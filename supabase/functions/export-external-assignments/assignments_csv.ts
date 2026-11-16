// Generación del CSV de asignaciones de territorio para herramientas externas
// (NW Scheduler: Territories > Import > "Territory Assignment Records from CSV file").
//
// NW Scheduler identifica el territorio por TerritoryID y al publicador por su
// DisplayName exacto, así que cada movimiento usa territories.external_id y
// persons.external_name. Lo que no tenga esos datos se omite y se informa aparte.
//
// Lógica pura (sin red ni base de datos) para poder probarla con `deno test`.

export type ExportTransaction = {
  id: number;
  givenAt: string;
  pickedAt: string | null;
  territoryCode: string;
  territoryExternalId: string | null;
  personName: string;
  personExternalName: string | null;
};

export type SkipReason = "TERRITORY_WITHOUT_EXTERNAL_ID" | "PERSON_WITHOUT_EXTERNAL_NAME";

export type SkippedTransaction = {
  transactionId: number;
  territoryCode: string;
  personName: string;
  givenAt: string;
  pickedAt: string | null;
  reasons: SkipReason[];
};

export type AssignmentsExport = {
  csv: string;
  rowCount: number;
  deliveries: number;
  returns: number;
  skipped: SkippedTransaction[];
};

export const CSV_HEADER = [
  "TerritoryID",
  "TerritoryNumber",
  "DateAssigned",
  "DateCompleted",
  "Publisher",
] as const;

// NW Scheduler exporta en UTF-8 con BOM y saltos CRLF; se replica el formato.
const BOM = "\uFEFF";
const EOL = "\r\n";

export function csvField(value: string): string {
  if (/[",\r\n]/.test(value) || value !== value.trim()) {
    return `"${value.replaceAll('"', '""')}"`;
  }
  return value;
}

// Fecha local (yyyy/MM/dd) en la zona horaria indicada.
export function formatExternalDate(iso: string, timeZone: string): string {
  const parts = new Intl.DateTimeFormat("en-CA", {
    timeZone,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).formatToParts(new Date(iso));
  const get = (type: string) => parts.find((p) => p.type === type)?.value ?? "";
  return `${get("year")}/${get("month")}/${get("day")}`;
}

// Número del territorio a partir del código de la app (AV001 -> 1, LU012 -> 12).
export function territoryNumber(code: string): string {
  const match = code.trim().match(/(\d+)\s*$/);
  return match ? String(Number(match[1])) : "";
}

export function isValidTimeZone(timeZone: string): boolean {
  try {
    new Intl.DateTimeFormat("en-US", { timeZone });
    return true;
  } catch {
    return false;
  }
}

const DATE_ONLY = /^(\d{4})-(\d{2})-(\d{2})$/;

export function isDateOnly(value: unknown): value is string {
  if (typeof value !== "string") return false;
  const match = value.match(DATE_ONLY);
  if (!match) return false;
  const [y, m, d] = [Number(match[1]), Number(match[2]), Number(match[3])];
  const date = new Date(Date.UTC(y, m - 1, d));
  return date.getUTCFullYear() === y && date.getUTCMonth() === m - 1 && date.getUTCDate() === d;
}

// Diferencia (ms) entre la hora local de `timeZone` y UTC en el instante dado.
function timeZoneOffset(instant: number, timeZone: string): number {
  const parts = new Intl.DateTimeFormat("en-US", {
    timeZone,
    hourCycle: "h23",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit",
  }).formatToParts(new Date(instant));
  const get = (type: string) => Number(parts.find((p) => p.type === type)?.value ?? 0);
  const asUtc = Date.UTC(get("year"), get("month") - 1, get("day"), get("hour"), get("minute"), get("second"));
  return asUtc - Math.floor(instant / 1000) * 1000;
}

// Inicio (00:00:00.000) o fin (23:59:59.999) del día local `date` (yyyy-MM-dd) en
// `timeZone`, como instante UTC.
export function localDayBoundary(date: string, timeZone: string, endOfDay: boolean): Date {
  const [y, m, d] = date.split("-").map(Number);
  const wallClock = endOfDay
    ? Date.UTC(y, m - 1, d, 23, 59, 59, 999)
    : Date.UTC(y, m - 1, d, 0, 0, 0, 0);
  // Dos pasadas para acertar también en los cambios de horario.
  let instant = wallClock - timeZoneOffset(wallClock, timeZone);
  instant = wallClock - timeZoneOffset(instant, timeZone);
  return new Date(instant);
}

function inRange(iso: string | null, start: Date, end: Date): boolean {
  if (!iso) return false;
  const time = new Date(iso).getTime();
  return time >= start.getTime() && time <= end.getTime();
}

// Un movimiento por transacción con entrega o devolución dentro del rango. La
// devolución solo se incluye si ocurrió antes del fin del rango (estado a esa
// fecha); si fue posterior, la fila sale como "sigue entregado".
export function buildAssignmentsExport(
  transactions: ExportTransaction[],
  start: Date,
  end: Date,
  timeZone: string,
): AssignmentsExport {
  const lines: string[] = [CSV_HEADER.join(",")];
  const skipped: SkippedTransaction[] = [];
  let deliveries = 0;
  let returns = 0;

  const relevant = transactions
    .filter((tx) => inRange(tx.givenAt, start, end) || inRange(tx.pickedAt, start, end))
    .sort((a, b) =>
      a.territoryCode.localeCompare(b.territoryCode, "es", { numeric: true }) ||
      new Date(a.givenAt).getTime() - new Date(b.givenAt).getTime() ||
      a.id - b.id
    );

  for (const tx of relevant) {
    const reasons: SkipReason[] = [];
    if (!tx.territoryExternalId?.trim()) reasons.push("TERRITORY_WITHOUT_EXTERNAL_ID");
    if (!tx.personExternalName?.trim()) reasons.push("PERSON_WITHOUT_EXTERNAL_NAME");
    if (reasons.length > 0) {
      skipped.push({
        transactionId: tx.id,
        territoryCode: tx.territoryCode,
        personName: tx.personName,
        givenAt: tx.givenAt,
        pickedAt: tx.pickedAt,
        reasons,
      });
      continue;
    }

    const completed = tx.pickedAt && new Date(tx.pickedAt).getTime() <= end.getTime()
      ? formatExternalDate(tx.pickedAt, timeZone)
      : "";

    if (inRange(tx.givenAt, start, end)) deliveries++;
    if (completed && inRange(tx.pickedAt, start, end)) returns++;

    lines.push([
      csvField(tx.territoryExternalId!.trim()),
      csvField(territoryNumber(tx.territoryCode)),
      formatExternalDate(tx.givenAt, timeZone),
      completed,
      // El nombre va tal cual (con sus espacios): NW Scheduler exige coincidencia exacta.
      csvField(tx.personExternalName!),
    ].join(","));
  }

  return {
    csv: BOM + lines.join(EOL) + EOL,
    rowCount: lines.length - 1,
    deliveries,
    returns,
    skipped,
  };
}

export function exportFileName(startDate: string, endDate: string): string {
  const compact = (d: string) => d.replaceAll("-", "");
  return `NWScheduler_Asignaciones_${compact(startDate)}-${compact(endDate)}.csv`;
}
