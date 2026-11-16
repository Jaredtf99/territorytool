import { Component, OnDestroy, OnInit } from '@angular/core';
import { Router } from '@angular/router';
import { EMPTY, Subject, Subscription } from 'rxjs';
import { catchError, debounceTime, switchMap } from 'rxjs/operators';
import { NgxSpinnerService } from 'ngx-spinner';
import { ToastrService } from 'ngx-toastr';
import { ExternalExportService } from '../../shared/external-export.service';
import {
  EXTERNAL_SKIP_REASON_LABELS,
  ExternalExportSkipped,
  ExternalExportSummary,
  ExternalSkipReason
} from '../../classes/ExternalExport';

/**
 * Exportación de entregas y devoluciones a CSV para importarlas en NW Scheduler
 * (Territorios → Importar → "Territory Assignment Records from CSV file").
 */
@Component({
  selector: 'export-external',
  templateUrl: './export-external.component.html',
  styleUrls: ['./export-external.component.css']
})
export class ExportExternalComponent implements OnInit, OnDestroy {

  startDate = '';
  endDate = '';
  summary?: ExternalExportSummary;
  loading = false;
  previewError = '';

  private previewRequests = new Subject<{ start?: string; end?: string }>();
  private previewSub?: Subscription;

  constructor(
    private exportService: ExternalExportService,
    private spinner: NgxSpinnerService,
    private toastr: ToastrService,
    private router: Router
  ) { }

  ngOnInit(): void {
    this.previewSub = this.previewRequests.pipe(
      debounceTime(250),
      switchMap(({ start, end }) => {
        this.loading = true;
        this.previewError = '';
        return this.exportService.preview(start, end).pipe(
          catchError(err => {
            this.handlePreviewError(err);
            return EMPTY;
          })
        );
      })
    ).subscribe(summary => this.applySummary(summary));
    // Sin fechas: el servidor propone desde la última exportación hasta hoy.
    this.previewRequests.next({});
  }

  ngOnDestroy(): void {
    this.previewSub?.unsubscribe();
  }

  get rangeInvalid(): boolean {
    return !!this.startDate && !!this.endDate && this.startDate > this.endDate;
  }

  onDatesChanged() {
    if (!this.startDate || !this.endDate || this.rangeInvalid) {
      this.summary = undefined;
      return;
    }
    this.previewRequests.next({ start: this.startDate, end: this.endDate });
  }

  download() {
    if (!this.startDate || !this.endDate || this.rangeInvalid) return;
    this.spinner.show();
    this.exportService.download(this.startDate, this.endDate).subscribe({
      next: file => {
        this.saveFile(file.fileName, file.csv);
        this.applySummary(file);
        this.spinner.hide();
        this.toastr.success(`${file.rowCount} movimientos exportados`);
        // Refresca "última exportación".
        this.previewRequests.next({ start: this.startDate, end: this.endDate });
      },
      error: err => {
        this.spinner.hide();
        this.toastr.error(errorMessage(err));
      }
    });
  }

  reasonLabel(reason: ExternalSkipReason): string {
    return EXTERNAL_SKIP_REASON_LABELS[reason] ?? reason;
  }

  trackBySkipped(_: number, item: ExternalExportSkipped) {
    return item.transactionId;
  }

  goToTerritories() {
    this.router.navigate(['/territories']);
  }

  goToPersons() {
    this.router.navigate(['/persons']);
  }

  private applySummary(summary: ExternalExportSummary) {
    this.loading = false;
    this.summary = summary;
    if (!this.startDate) this.startDate = summary.startDate;
    if (!this.endDate) this.endDate = summary.endDate;
  }

  private handlePreviewError(err: any) {
    this.loading = false;
    this.summary = undefined;
    this.previewError = errorMessage(err);
  }

  private saveFile(fileName: string, csv: string) {
    const blob = new Blob([csv], { type: 'text/csv;charset=utf-8' });
    const link = document.createElement('a');
    link.href = URL.createObjectURL(blob);
    link.download = fileName;
    link.click();
    setTimeout(() => URL.revokeObjectURL(link.href), 1000);
  }
}

function errorMessage(err: any): string {
  const code = String(err?.message ?? '');
  switch (code) {
    case 'FORBIDDEN': return 'Solo los administradores pueden exportar.';
    case 'START_DATE_GREATER_THAN_END': return 'La fecha "Desde" no puede ser posterior a "Hasta".';
    case 'RANGE_TOO_LARGE': return 'Demasiados movimientos: reduce el rango de fechas.';
    case 'INVALID_PARAMETERS': return 'Fechas no válidas.';
    default: return 'No se pudo preparar la exportación.';
  }
}
