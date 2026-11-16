import { Injectable } from '@angular/core';
import { from, Observable } from 'rxjs';
import { SupabaseService } from './supabase.service';
import { ExternalExportFile, ExternalExportSummary } from '../classes/ExternalExport';

/** Exportación de movimientos para NW Scheduler (edge function `export-external-assignments`). */
@Injectable()
export class ExternalExportService {

  constructor(private supabase: SupabaseService) { }

  /** Sin fechas, el servidor propone desde la última exportación hasta hoy. */
  preview(startDate?: string, endDate?: string): Observable<ExternalExportSummary> {
    return from(this.invoke('preview', startDate, endDate).then(mapSummary));
  }

  download(startDate: string, endDate: string): Observable<ExternalExportFile> {
    return from(this.invoke('download', startDate, endDate).then(raw => ({
      ...mapSummary(raw),
      fileName: raw.fileName,
      csv: raw.csv
    })));
  }

  private async invoke(mode: 'preview' | 'download', startDate?: string, endDate?: string): Promise<any> {
    const timeZone = Intl.DateTimeFormat().resolvedOptions().timeZone || 'Europe/Madrid';
    const body: any = { mode, timeZone };
    if (startDate && endDate) {
      body.startDate = startDate;
      body.endDate = endDate;
    }
    const { data, error } = await this.supabase.client.functions.invoke('export-external-assignments', { body });
    if (error) {
      throw new Error(await errorCode(error));
    }
    return data;
  }
}

/** Código de error que devuelve la función (`{ error: "..." }`), si se puede leer. */
async function errorCode(error: any): Promise<string> {
  try {
    const payload = await error?.context?.json?.();
    if (payload?.error) return String(payload.error);
  } catch { /* cuerpo no JSON */ }
  return String(error?.message ?? 'UNKNOWN_ERROR');
}

const toDate = (value: any): Date | undefined => (value ? new Date(value) : undefined);

function mapSummary(raw: any): ExternalExportSummary {
  const last = raw?.lastExport;
  return {
    startDate: raw?.startDate,
    endDate: raw?.endDate,
    timeZone: raw?.timeZone,
    rowCount: raw?.rowCount ?? 0,
    deliveries: raw?.deliveries ?? 0,
    returns: raw?.returns ?? 0,
    skipped: (raw?.skipped ?? []).map((s: any) => ({
      transactionId: s.transactionId,
      territoryCode: s.territoryCode,
      personName: s.personName,
      givenAt: new Date(s.givenAt),
      pickedAt: toDate(s.pickedAt),
      reasons: s.reasons ?? []
    })),
    lastExport: last ? {
      exportedAt: new Date(last.exportedAt),
      rangeStart: new Date(last.rangeStart),
      rangeEnd: new Date(last.rangeEnd),
      rowCount: last.rowCount ?? 0,
      skippedCount: last.skippedCount ?? 0
    } : null
  };
}
