import {
  adminClient,
  corsHeaders,
  ensureCongregationAdmin,
  ensureCongregationMember,
  jsonResponse,
  readJson,
} from "../_shared/http.ts";
import { Image } from "imagescript";

// Geoapify stamps a "Powered by Geoapify" attribution band along the bottom of
// the static map. The original .NET backend cropped it off; we replicate that
// by trimming the bottom WATERMARK_HEIGHT pixels (matched to scaleFactor=2).
const WATERMARK_HEIGHT = 80;

type RefreshRequest = {
  territoryId?: number;
  geometryOnly?: boolean;
  syncAllGeometry?: boolean;
};

type Coordinate = {
  latitude: number;
  longitude: number;
};

type MapFeature = {
  id: string;
  name?: string;
  description?: string;
  coordinates: Coordinate[];
};

type MapMarker = {
  id: string;
  title?: string;
  description?: string;
  latitude: number;
  longitude: number;
};

type MapGeometry = {
  version: 1;
  bounds: {
    south: number;
    west: number;
    north: number;
    east: number;
  };
  polygons: MapFeature[];
  polylines: MapFeature[];
  markers: MapMarker[];
};

function decodeXml(value: string | undefined): string | undefined {
  if (!value) return undefined;

  const decoded = value
    .replace(/<!\[CDATA\[([\s\S]*?)\]\]>/g, "$1")
    .replace(/<[^>]+>/g, "")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&quot;/g, '"')
    .replace(/&apos;/g, "'")
    .replace(/&#39;/g, "'")
    .replace(/&amp;/g, "&")
    .trim();

  return decoded || undefined;
}

function elementText(xml: string, tag: string): string | undefined {
  const match = xml.match(
    new RegExp(`<${tag}(?:\\s[^>]*)?>([\\s\\S]*?)<\\/${tag}>`, "i"),
  );
  return decodeXml(match?.[1]);
}

function parseCoordinates(value: string | undefined): Coordinate[] {
  if (!value) return [];

  return value
    .trim()
    .split(/\s+/)
    .map((tuple) => {
      const [longitude, latitude] = tuple.split(",").map(Number);
      return { latitude, longitude };
    })
    .filter((coordinate) =>
      Number.isFinite(coordinate.latitude) &&
      Number.isFinite(coordinate.longitude) &&
      coordinate.latitude >= -90 &&
      coordinate.latitude <= 90 &&
      coordinate.longitude >= -180 &&
      coordinate.longitude <= 180
    );
}

function coordinatesFromElement(xml: string): Coordinate[] {
  const match = xml.match(
    /<coordinates(?:\s[^>]*)?>([\s\S]*?)<\/coordinates>/i,
  );
  return parseCoordinates(match?.[1]);
}

export function getGoogleMyMapsId(mapUrl: string): string | null {
  try {
    const url = new URL(mapUrl);
    return url.searchParams.get("mid");
  } catch {
    return null;
  }
}

async function getGeometryFromMapUrl(
  mapUrl: string,
): Promise<MapGeometry | null> {
  const mapId = getGoogleMyMapsId(mapUrl);
  if (!mapId) return null;

  const kmlUrl = new URL("https://www.google.com/maps/d/kml");
  kmlUrl.searchParams.set("mid", mapId);
  kmlUrl.searchParams.set("forcekml", "1");

  const response = await fetch(kmlUrl);
  if (!response.ok) return null;
  return parseKml(await response.text());
}

export function parseKml(kml: string): MapGeometry | null {
  const polygons: MapFeature[] = [];
  const polylines: MapFeature[] = [];
  const markers: MapMarker[] = [];

  const placemarks =
    kml.match(/<Placemark(?:\s[^>]*)?>[\s\S]*?<\/Placemark>/gi) ?? [];
  for (const placemark of placemarks) {
    const name = elementText(placemark, "name");
    const description = elementText(placemark, "description");

    const polygonBlocks =
      placemark.match(/<Polygon(?:\s[^>]*)?>[\s\S]*?<\/Polygon>/gi) ?? [];
    for (const polygonBlock of polygonBlocks) {
      const outerBoundary = polygonBlock.match(
        /<outerBoundaryIs(?:\s[^>]*)?>[\s\S]*?<\/outerBoundaryIs>/i,
      )?.[0] ?? polygonBlock;
      const coordinates = coordinatesFromElement(outerBoundary);
      if (coordinates.length >= 3) {
        polygons.push({
          id: `polygon-${polygons.length + 1}`,
          name,
          description,
          coordinates,
        });
      }
    }

    const lineBlocks =
      placemark.match(/<LineString(?:\s[^>]*)?>[\s\S]*?<\/LineString>/gi) ?? [];
    for (const lineBlock of lineBlocks) {
      const coordinates = coordinatesFromElement(lineBlock);
      if (coordinates.length >= 2) {
        polylines.push({
          id: `polyline-${polylines.length + 1}`,
          name,
          description,
          coordinates,
        });
      }
    }

    const pointBlocks =
      placemark.match(/<Point(?:\s[^>]*)?>[\s\S]*?<\/Point>/gi) ?? [];
    for (const pointBlock of pointBlocks) {
      const coordinate = coordinatesFromElement(pointBlock)[0];
      if (coordinate) {
        markers.push({
          id: `marker-${markers.length + 1}`,
          title: name,
          description,
          latitude: coordinate.latitude,
          longitude: coordinate.longitude,
        });
      }
    }
  }

  const coordinates = [
    ...polygons.flatMap((polygon) => polygon.coordinates),
    ...polylines.flatMap((polyline) => polyline.coordinates),
    ...markers.map(({ latitude, longitude }) => ({ latitude, longitude })),
  ];
  const box = getBoundingBox(coordinates);
  if (
    !box ||
    (polygons.length === 0 && polylines.length === 0 && markers.length === 0)
  ) {
    return null;
  }

  return {
    version: 1,
    bounds: {
      south: box.southwest.latitude,
      west: box.southwest.longitude,
      north: box.northeast.latitude,
      east: box.northeast.longitude,
    },
    polygons,
    polylines,
    markers,
  };
}

function getBoundingBox(coordinates: Coordinate[]) {
  if (coordinates.length === 0) return null;

  return coordinates.reduce(
    (box, coordinate) => ({
      southwest: {
        latitude: Math.min(box.southwest.latitude, coordinate.latitude),
        longitude: Math.min(box.southwest.longitude, coordinate.longitude),
      },
      northeast: {
        latitude: Math.max(box.northeast.latitude, coordinate.latitude),
        longitude: Math.max(box.northeast.longitude, coordinate.longitude),
      },
    }),
    {
      southwest: { ...coordinates[0] },
      northeast: { ...coordinates[0] },
    },
  );
}

if (import.meta.main) {
  Deno.serve(async (req) => {
    if (req.method === "OPTIONS") {
      return new Response("ok", { headers: corsHeaders });
    }

    if (req.method !== "POST") {
      return jsonResponse({ error: "METHOD_NOT_ALLOWED" }, 405);
    }

    try {
      const { territoryId, geometryOnly = false, syncAllGeometry = false } =
        await readJson<
          RefreshRequest
        >(req);
      const actor = geometryOnly || syncAllGeometry
        ? await ensureCongregationMember(req)
        : await ensureCongregationAdmin(req);
      const userId = actor.userId;

      if (!territoryId && !syncAllGeometry) {
        return jsonResponse({ error: "INVALID_PARAMETERS" }, 400);
      }

      const supabase = adminClient();

      if (syncAllGeometry) {
        const { data: territories, error: territoriesError } = await supabase
          .from("territories")
          .select("id, map_url")
          .eq("congregation_id", actor.congregationId!)
          .eq("archived", false)
          .is("map_geometry", null);

        if (territoriesError) {
          return jsonResponse({ error: territoriesError.message }, 400);
        }

        let synced = 0;
        const failed: number[] = [];
        const pending = territories ?? [];

        for (let index = 0; index < pending.length; index += 10) {
          const batch = pending.slice(index, index + 10);
          const results = await Promise.all(
            batch.map(async (territory) => {
              try {
                const geometry = await getGeometryFromMapUrl(territory.map_url);
                if (!geometry) return false;

                const { error } = await supabase
                  .from("territories")
                  .update({ map_geometry: geometry })
                  .eq("id", territory.id)
                  .eq("congregation_id", actor.congregationId!);
                return !error;
              } catch {
                return false;
              }
            }),
          );

          results.forEach((success, resultIndex) => {
            if (success) {
              synced += 1;
            } else {
              failed.push(batch[resultIndex].id);
            }
          });
        }

        return jsonResponse({ synced, failed, total: pending.length });
      }

      const { data: territory, error: territoryError } = await supabase
        .from("territories")
        .select("id, code, name, map_url, image_path")
        .eq("id", territoryId)
        .eq("congregation_id", actor.congregationId!)
        .single();

      if (territoryError || !territory) {
        return jsonResponse({ error: "TERRITORY_NOT_FOUND" }, 404);
      }

      if (!getGoogleMyMapsId(territory.map_url)) {
        return jsonResponse({ error: "UNSUPPORTED_MAP_URL" }, 400);
      }

      let geometry: MapGeometry | null;
      try {
        geometry = await getGeometryFromMapUrl(territory.map_url);
      } catch (_e) {
        return jsonResponse({ error: "MAP_URL_FETCH_FAILED" }, 400);
      }
      if (!geometry) {
        return jsonResponse({ error: "MAP_COORDINATES_NOT_FOUND" }, 400);
      }

      const { error: geometryUpdateError } = await supabase
        .from("territories")
        .update({ map_geometry: geometry })
        .eq("id", territory.id)
        .eq("congregation_id", actor.congregationId!);
      if (geometryUpdateError) {
        return jsonResponse({ error: geometryUpdateError.message }, 400);
      }

      if (geometryOnly) {
        return jsonResponse({
          geometry,
          imagePath: territory.image_path ?? null,
          signedUrl: null,
        });
      }

      // Keep generating the legacy image when Geoapify is configured. The iOS
      // detail view uses MapKit, while cards and older clients can keep using it.
      const apiKey = Deno.env.get("GEOAPIFY_API_KEY");
      if (!apiKey) {
        return jsonResponse({ geometry, imagePath: null, signedUrl: null });
      }

      const staticMapUrl = new URL("https://maps.geoapify.com/v1/staticmap");
      staticMapUrl.searchParams.set("style", "maptiler-3d");
      staticMapUrl.searchParams.set("scaleFactor", "2");
      staticMapUrl.searchParams.set("width", "420");
      staticMapUrl.searchParams.set("height", "280");
      staticMapUrl.searchParams.set("pitch", "40");
      staticMapUrl.searchParams.set(
        "area",
        `rect:${geometry.bounds.west},${geometry.bounds.south},${geometry.bounds.east},${geometry.bounds.north}`,
      );
      staticMapUrl.searchParams.set("apiKey", apiKey);
      staticMapUrl.searchParams.set(
        "styleCustomization",
        "background:#f9f1e6|landcover_grass:#aee77e|water:#8cd6f6|road_minor:#9a9ea1|road_trunk_primary:#9a9ea1|road_secondary_tertiary:#9a9ea1|road_major_motorway:#9a9ea1|bridge_major:#9a9ea1|building-3d:#e8ebe1",
      );

      let imageResponse: Response;
      try {
        imageResponse = await fetch(staticMapUrl);
      } catch (_e) {
        return jsonResponse({ error: "IMAGE_GENERATION_FAILED" }, 502);
      }
      if (!imageResponse.ok) {
        return jsonResponse({ error: "IMAGE_GENERATION_FAILED" }, 502);
      }

      const rawBytes = new Uint8Array(await imageResponse.arrayBuffer());

      // Crop the Geoapify attribution band off the bottom and re-encode to PNG.
      let imageBytes: Uint8Array = rawBytes;
      try {
        const image = await Image.decode(rawBytes);
        const cropHeight = Math.max(1, image.height - WATERMARK_HEIGHT);
        image.crop(0, 0, image.width, cropHeight);
        imageBytes = await image.encode();
      } catch (_e) {
        return jsonResponse({ error: "IMAGE_PROCESSING_FAILED" }, 502);
      }

      const imagePath = `${territory.id}/${crypto.randomUUID()}.png`;
      const { error: uploadError } = await supabase.storage
        .from("territory-images")
        .upload(imagePath, imageBytes, {
          contentType: "image/png",
          upsert: false,
        });
      if (uploadError) {
        return jsonResponse({ error: uploadError.message }, 400);
      }

      const { error: updateError } = await supabase
        .from("territories")
        .update({ image_path: imagePath })
        .eq("id", territory.id);
      if (updateError) {
        return jsonResponse({ error: updateError.message }, 400);
      }

      await supabase.rpc("add_action_log", {
        p_action_type: 13,
        p_message: `Refreshed image territory ID ${territory.id}`,
        p_user_id: userId,
        p_successful: true,
      });

      const { data: signed } = await supabase.storage
        .from("territory-images")
        .createSignedUrl(imagePath, 60 * 60);

      return jsonResponse({
        geometry,
        imagePath,
        signedUrl: signed?.signedUrl,
      });
    } catch (error) {
      if (error instanceof Response) return error;
      console.error("refresh-territory-image failed", error);
      return jsonResponse({ error: "INTERNAL_ERROR" }, 500);
    }
  });
}
