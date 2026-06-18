import * as XLSX from "npm:xlsx@0.18.5";
import { adminClient, authenticatedClient, corsHeaders, getActorContext, jsonResponse, readJson } from "../_shared/http.ts";

type ReportRequest = {
  start?: string;
  end?: string;
};

function parseDate(value?: string): Date | null {
  if (!value) return null;
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? null : date;
}

function formatTimestampForFile(date = new Date()): string {
  return date.toISOString().replaceAll("-", "").replaceAll(":", "").slice(0, 14);
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return jsonResponse({ error: "METHOD_NOT_ALLOWED" }, 405);
  }

  try {
    const { userId } = await authenticatedClient(req);
    const actor = await getActorContext(userId);
    if (!actor.congregationId) {
      return jsonResponse({ error: "NO_ACTIVE_CONGREGATION" }, 403);
    }

    const body = await readJson<ReportRequest>(req);
    const start = parseDate(body.start);
    const end = parseDate(body.end);
    if (!start || !end) {
      return jsonResponse({ error: "INVALID_PARAMETERS" }, 400);
    }
    if (start > end) {
      return jsonResponse({ error: "START_DATE_GREATER_THAN_END" }, 400);
    }

    const supabase = adminClient();
    const { data, error } = await supabase
      .from("territory_details")
      .select("territory_id, territory_name:name, code, person_name, given_at, picked_at")
      .eq("congregation_id", actor.congregationId)
      .or(`and(given_at.gte.${start.toISOString()},given_at.lte.${end.toISOString()}),and(picked_at.gte.${start.toISOString()},picked_at.lte.${end.toISOString()})`)
      .order("territory_id", { ascending: true })
      .order("given_at", { ascending: true });

    if (error) {
      return jsonResponse({ error: error.message }, 400);
    }

    const grouped = new Map<string, Array<Record<string, unknown>>>();
    for (const row of data ?? []) {
      const key = `${row.code} ${row.territory_name}`;
      if (!grouped.has(key)) grouped.set(key, []);
      grouped.get(key)!.push(row);
    }

    const sheetRows: Array<Record<string, unknown>> = [];
    for (const [territory, rows] of grouped.entries()) {
      sheetRows.push({ Territory: territory, GivenDate: "", PickedDate: "", Person: "" });
      for (const row of rows) {
        sheetRows.push({
          Territory: "",
          GivenDate: row.given_at ? new Date(String(row.given_at)).toISOString().slice(0, 10) : "",
          PickedDate: row.picked_at ? new Date(String(row.picked_at)).toISOString().slice(0, 10) : "",
          Person: row.person_name ?? "",
        });
      }
      sheetRows.push({ Territory: "", GivenDate: "", PickedDate: "", Person: "" });
    }

    const workbook = XLSX.utils.book_new();
    const worksheet = XLSX.utils.json_to_sheet(sheetRows, {
      header: ["Territory", "GivenDate", "PickedDate", "Person"],
    });
    worksheet["!cols"] = [{ wch: 32 }, { wch: 14 }, { wch: 14 }, { wch: 28 }];
    XLSX.utils.book_append_sheet(workbook, worksheet, "TerritoryTransactions");

    const bytes = XLSX.write(workbook, { bookType: "xlsx", type: "array" }) as ArrayBuffer;
    const fileName = `TerritoryTransactions_${formatTimestampForFile()}.xlsx`;

    return new Response(bytes, {
      headers: {
        ...corsHeaders,
        "Content-Type": "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        "Content-Disposition": `attachment; filename="${fileName}"`,
      },
    });
  } catch (error) {
    if (error instanceof Response) return error;
    console.error("generate-territory-report failed", error);
    return jsonResponse({ error: "INTERNAL_ERROR" }, 500);
  }
});
