/** Datos de sincronización de un hermano con la herramienta externa (NW Scheduler). */
export interface PersonExternalInfo {
  externalId: string | null;
  /** DisplayName exacto en NW Scheduler (se respeta tal cual, espacios incluidos). */
  externalName: string | null;
}

export type ExternalSkipReason = 'TERRITORY_WITHOUT_EXTERNAL_ID' | 'PERSON_WITHOUT_EXTERNAL_NAME';

export interface ExternalExportSkipped {
  transactionId: number;
  territoryCode: string;
  personName: string;
  givenAt: Date;
  pickedAt?: Date;
  reasons: ExternalSkipReason[];
}

export interface ExternalExportLast {
  exportedAt: Date;
  rangeStart: Date;
  rangeEnd: Date;
  rowCount: number;
  skippedCount: number;
}

export interface ExternalExportSummary {
  /** yyyy-MM-dd */
  startDate: string;
  /** yyyy-MM-dd */
  endDate: string;
  timeZone: string;
  rowCount: number;
  deliveries: number;
  returns: number;
  skipped: ExternalExportSkipped[];
  lastExport: ExternalExportLast | null;
}

export interface ExternalExportFile extends ExternalExportSummary {
  fileName: string;
  csv: string;
}

export const EXTERNAL_SKIP_REASON_LABELS: Record<ExternalSkipReason, string> = {
  TERRITORY_WITHOUT_EXTERNAL_ID: 'Territorio sin ID de NW Scheduler',
  PERSON_WITHOUT_EXTERNAL_NAME: 'Hermano sin nombre de NW Scheduler'
};
