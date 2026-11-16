// Exporta los movimientos (entregas y devoluciones) de la congregación activa en el
// formato CSV que importa NW Scheduler. Solo para administradores.
//
// POST { mode?: "preview" | "download", startDate?: "yyyy-MM-dd", endDate?: "yyyy-MM-dd",
//        timeZone?: string }
//
// - Sin fechas: desde el día siguiente a la última exportación (o hoy) hasta hoy.
// - preview: recuento de filas, movimientos omitidos y última exportación.
// - download: lo mismo más `fileName` y `csv`, y registra la exportación en
//   external_exports.
import {
  adminClient,
  corsHeaders,
  ensureCongregationAdmin,
  jsonResponse,
  readJson,
} from "../_shared/http.ts";
import {
  buildAssignmentsExport,
  type ExportTransaction,
  exportFileName,
  formatExternalDate,
  isDateOnly,
  isValidTimeZone,
  localDayBoundary,
} from "./assignments_csv.ts";

type ExportRequest = {
  mode?: "preview" | "download";
  startDate?: string;
  endDate?: string;
  timeZone?: string;
};

type LastExport = {
  exportedAt: string;
  rangeStart: string;
  rangeEnd: string;
  rowCount: number;
  skippedCount: number;
};

const DEFAULT_TIME_ZONE = "Europe/Madrid";
const MAX_TRANSACTIONS = 5000;

function toDateOnly(iso: string, timeZone: string): string {
  return formatExternalDate(iso, timeZone).replaceAll("/", "-");
}

function addDays(date: string, days: number): string {
  const [y, m, d] = date.split("-").map(Number);
  const next = new Date(Date.UTC(y, m - 1, d + days));
  return next.toISOString().slice(0, 10);
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return jsonResponse({ error: "METHOD_NOT_ALLOWED" }, 405);
  }

  try {
    const actor = await ensureCongregationAdmin(req);
    const congregationId = actor.congregationId!;
    const body = await readJson<ExportRequest>(req);

    const mode = body.mode ?? "preview";
    if (mode !== "preview" && mode !== "download") {
      return jsonResponse({ error: "INVALID_PARAMETERS" }, 400);
    }

    const timeZone = body.timeZone?.trim() || DEFAULT_TIME_ZONE;
    if (!isValidTimeZone(timeZone)) {
      return jsonResponse({ error: "INVALID_TIME_ZONE" }, 400);
    }

    const supabase = adminClient();

    const { data: lastRow, error: lastError } = await supabase
      .from("external_exports")
      .select("exported_at, range_start, range_end, row_count, skipped_count")
      .eq("congregation_id", congregationId)
      .order("exported_at", { ascending: false })
      .limit(1)
      .maybeSingle();
    if (lastError) {
      return jsonResponse({ error: lastError.message }, 400);
    }
    const lastExport: LastExport | null = lastRow
      ? {
        exportedAt: lastRow.exported_at,
        rangeStart: lastRow.range_start,
        rangeEnd: lastRow.range_end,
        rowCount: lastRow.row_count,
        skippedCount: lastRow.skipped_count,
      }
      : null;

    const today = toDateOnly(new Date().toISOString(), timeZone);
    let startDate = body.startDate;
    let endDate = body.endDate;
    if (startDate === undefined && endDate === undefined) {
      endDate = today;
      startDate = lastExport ? addDays(toDateOnly(lastExport.rangeEnd, timeZone), 1) : today;
      if (startDate > endDate) startDate = endDate;
    }
    if (!isDateOnly(startDate) || !isDateOnly(endDate)) {
      return jsonResponse({ error: "INVALID_PARAMETERS" }, 400);
    }
    if (startDate > endDate) {
      return jsonResponse({ error: "START_DATE_GREATER_THAN_END" }, 400);
    }

    const start = localDayBoundary(startDate, timeZone, false);
    const end = localDayBoundary(endDate, timeZone, true);
    const startIso = start.toISOString();
    const endIso = end.toISOString();

    const { data, error } = await supabase
      .from("territory_transactions")
      .select(
        "id, given_at, picked_at, territory:territories!inner(code, external_id), person:persons!inner(name, external_name)",
      )
      .eq("congregation_id", congregationId)
      .or(
        `and(given_at.gte.${startIso},given_at.lte.${endIso}),and(picked_at.gte.${startIso},picked_at.lte.${endIso})`,
      )
      .order("given_at", { ascending: true })
      .range(0, MAX_TRANSACTIONS - 1);
    if (error) {
      return jsonResponse({ error: error.message }, 400);
    }
    if ((data?.length ?? 0) >= MAX_TRANSACTIONS) {
      return jsonResponse({ error: "RANGE_TOO_LARGE" }, 400);
    }

    // deno-lint-ignore no-explicit-any
    const transactions: ExportTransaction[] = (data ?? []).map((row: any) => ({
      id: row.id,
      givenAt: row.given_at,
      pickedAt: row.picked_at,
      territoryCode: row.territory.code,
      territoryExternalId: row.territory.external_id,
      personName: row.person.name,
      personExternalName: row.person.external_name,
    }));

    const result = buildAssignmentsExport(transactions, start, end, timeZone);
    const summary = {
      startDate,
      endDate,
      timeZone,
      rowCount: result.rowCount,
      deliveries: result.deliveries,
      returns: result.returns,
      skipped: result.skipped,
      lastExport,
    };

    if (mode === "preview") {
      return jsonResponse(summary);
    }

    const { error: insertError } = await supabase.from("external_exports").insert({
      congregation_id: congregationId,
      exported_by: actor.userId,
      range_start: startIso,
      range_end: endIso,
      row_count: result.rowCount,
      skipped_count: result.skipped.length,
    });
    if (insertError) {
      return jsonResponse({ error: insertError.message }, 400);
    }

    return jsonResponse({
      ...summary,
      fileName: exportFileName(startDate, endDate),
      csv: result.csv,
    });
  } catch (error) {
    if (error instanceof Response) return error;
    console.error("export-external-assignments failed", error);
    return jsonResponse({ error: "INTERNAL_ERROR" }, 500);
  }
});
