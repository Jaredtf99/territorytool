import { assertEquals } from "@std/assert";
import {
  buildAssignmentsExport,
  csvField,
  type ExportTransaction,
  isDateOnly,
  localDayBoundary,
  territoryNumber,
} from "./assignments_csv.ts";

const TZ = "Europe/Madrid";

function tx(partial: Partial<ExportTransaction>): ExportTransaction {
  return {
    id: 1,
    givenAt: "2026-11-17T10:00:00Z",
    pickedAt: null,
    territoryCode: "AV001",
    territoryExternalId: "6533450",
    personName: "Sheila Iglésias",
    personExternalName: "(Fernández) Iglesias del valle, Sheila",
    ...partial,
  };
}

Deno.test("localDayBoundary respeta la zona horaria y el cambio de hora", () => {
  assertEquals(localDayBoundary("2026-11-17", TZ, false).toISOString(), "2026-11-16T23:00:00.000Z");
  assertEquals(localDayBoundary("2026-11-17", TZ, true).toISOString(), "2026-11-17T22:59:59.999Z");
  assertEquals(localDayBoundary("2026-07-01", TZ, false).toISOString(), "2026-06-30T22:00:00.000Z");
  // 29/03/2026: cambio a horario de verano (02:00 -> 03:00).
  assertEquals(localDayBoundary("2026-03-29", TZ, true).toISOString(), "2026-03-29T21:59:59.999Z");
});

Deno.test("isDateOnly valida fechas reales", () => {
  assertEquals(isDateOnly("2026-11-17"), true);
  assertEquals(isDateOnly("2026-02-30"), false);
  assertEquals(isDateOnly("17/11/2026"), false);
  assertEquals(isDateOnly(undefined), false);
});

Deno.test("territoryNumber y csvField", () => {
  assertEquals(territoryNumber("AV001"), "1");
  assertEquals(territoryNumber("LU012"), "12");
  assertEquals(territoryNumber("RU105"), "105");
  assertEquals(csvField("6533450"), "6533450");
  assertEquals(csvField("Sosa, José "), '"Sosa, José "');
  assertEquals(csvField('a "b"'), '"a ""b"""');
  assertEquals(csvField('a, "b"'), '"a, ""b"""');
});

Deno.test("CSV con BOM, CRLF, fechas locales y nombre exacto", () => {
  const start = localDayBoundary("2026-11-17", TZ, false);
  const end = localDayBoundary("2026-11-30", TZ, true);
  const result = buildAssignmentsExport([
    // Entregado y devuelto dentro del rango; 23:30 UTC ya es día siguiente en Madrid.
    tx({ id: 1, givenAt: "2026-11-17T23:30:00Z", pickedAt: "2026-11-20T10:00:00Z" }),
    // Entregado antes del rango, devuelto dentro.
    tx({ id: 2, territoryCode: "RU003", territoryExternalId: "7787292", givenAt: "2026-07-24T08:00:00Z", pickedAt: "2026-11-18T09:00:00Z", personExternalName: "Vegas Marín, Hazael " }),
    // Entregado dentro, devuelto después del rango: sale como abierto.
    tx({ id: 3, territoryCode: "AV010", territoryExternalId: "3627565", givenAt: "2026-11-25T08:00:00Z", pickedAt: "2026-12-05T08:00:00Z" }),
    // Fuera del rango.
    tx({ id: 4, givenAt: "2026-10-01T08:00:00Z", pickedAt: "2026-10-05T08:00:00Z" }),
    // Abierto desde antes del rango: sin movimiento en el rango.
    tx({ id: 5, givenAt: "2026-09-01T08:00:00Z", pickedAt: null }),
  ], start, end, TZ);

  assertEquals(result.csv.startsWith("\uFEFF"), true);
  assertEquals(result.csv.split("\r\n"), [
    "\uFEFFTerritoryID,TerritoryNumber,DateAssigned,DateCompleted,Publisher",
    '6533450,1,2026/11/18,2026/11/20,"(Fernández) Iglesias del valle, Sheila"',
    '3627565,10,2026/11/25,,"(Fernández) Iglesias del valle, Sheila"',
    '7787292,3,2026/07/24,2026/11/18,"Vegas Marín, Hazael "',
    "",
  ]);
  assertEquals(result.rowCount, 3);
  assertEquals(result.deliveries, 2);
  assertEquals(result.returns, 2);
  assertEquals(result.skipped, []);
});

Deno.test("omite movimientos sin datos externos y lo informa", () => {
  const start = localDayBoundary("2026-11-17", TZ, false);
  const end = localDayBoundary("2026-11-17", TZ, true);
  const result = buildAssignmentsExport([
    tx({ id: 7, personName: "Conchita Alonso", personExternalName: null }),
    tx({ id: 8, territoryExternalId: " ", personExternalName: "" }),
  ], start, end, TZ);
  assertEquals(result.rowCount, 0);
  assertEquals(result.skipped.map((s) => [s.transactionId, s.reasons]), [
    [7, ["PERSON_WITHOUT_EXTERNAL_NAME"]],
    [8, ["TERRITORY_WITHOUT_EXTERNAL_ID", "PERSON_WITHOUT_EXTERNAL_NAME"]],
  ]);
});
