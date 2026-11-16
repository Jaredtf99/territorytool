import { Component, ElementRef, EventEmitter, Input, Output } from '@angular/core';
import { FormBuilder, FormGroup, Validators } from '@angular/forms';
import { ToastrService } from 'ngx-toastr';
import { TerritoryEditInfo } from '../../classes/TerritoryEditInfo';
import { NgxSpinnerService } from "ngx-spinner";
import { TerritoryService } from '../../shared/territory.service';

declare var $: any;

@Component({
  selector: 'edit-territory-modal',
  templateUrl: './edit-territory-modal.component.html'
})
export class EditTerritoryModalComponent {
  @Input() set territoryInfo(value: TerritoryEditInfo) {
    this._territoryInfo = value;
    this.initializeForm();
  }
  get territoryInfo(): TerritoryEditInfo {
    return this._territoryInfo;
  }
  private _territoryInfo!: TerritoryEditInfo;

  @Output() territoryUpdated: EventEmitter<void> = new EventEmitter<void>();

  editForm!: FormGroup;
  /** TerritoryID de NW Scheduler tal y como está guardado (para saber si cambia). */
  private originalExternalId: string | null = null;

  constructor(
    private toastr: ToastrService,
    private spinner: NgxSpinnerService,
    public territoryService: TerritoryService,
    private el: ElementRef,
    private fb: FormBuilder
  ) {}

  initializeForm(): void {
    this.editForm = this.fb.group({
      name: [this.territoryInfo.name, Validators.required],
      code: [this.territoryInfo.code, Validators.required],
      mapUrl: [this.territoryInfo.mapUrl, Validators.required],
      excludeFromSuggestions: [this.territoryInfo.excludeFromSuggestions ?? false],
      externalId: ['']
    });
    this.loadExternalId();
  }

  private loadExternalId(): void {
    this.originalExternalId = null;
    const id = this.territoryInfo?.id;
    if (!id) return;
    this.territoryService.getTerritoryExternalId(id).subscribe({
      next: externalId => {
        if (this.territoryInfo?.id !== id) return;
        this.originalExternalId = externalId;
        this.editForm.get('externalId')?.setValue(externalId ?? '', { emitEvent: false });
      },
      error: err => console.error(err)
    });
  }

  openModal(): void {
    $('#editTerritory').modal('show');
  }

  editTerritory() {
    if (this.editForm.invalid) {
      return;
    }

    this.spinner.show();
    const formValue = this.editForm.value;
    this.territoryService.editTerritory(
      this.territoryInfo.id!,
      formValue.mapUrl,
      formValue.name,
      formValue.code,
      formValue.excludeFromSuggestions === true
    ).subscribe({
      next: (res: any) => {
        if (res?.error) {
          this.spinner.hide();
          this.handleEditError({ error: res.error.message });
          return;
        }
        this.saveExternalIdIfChanged(formValue.externalId);
      },
      error: err => {
        this.spinner.hide();
        this.handleEditError(err);
      }
    });
  }

  private saveExternalIdIfChanged(rawExternalId: string): void {
    const externalId = (rawExternalId ?? '').trim() || null;
    const finish = () => {
      $('#editTerritory').modal('hide');
      this.territoryUpdated.emit();
      this.spinner.hide();
      this.toastr.success('Territorio editado');
    };
    if (externalId === this.originalExternalId) {
      finish();
      return;
    }
    this.territoryService.setTerritoryExternal(this.territoryInfo.id!, externalId).subscribe({
      next: () => {
        this.originalExternalId = externalId;
        finish();
      },
      error: err => {
        this.spinner.hide();
        if (String(err?.message ?? '').includes('EXTERNAL_ID_ALREADY_USED')) {
          this.editForm.get('externalId')?.setErrors({ externalIdExists: true });
        } else {
          this.toastr.error('El territorio se ha guardado, pero no el ID de NW Scheduler');
        }
      }
    });
  }

  private handleEditError(err: any): void {
    const error = err.error;

    // Limpiar errores previos
    this.editForm.get('name')?.setErrors(null);
    this.editForm.get('code')?.setErrors(null);
    this.editForm.get('mapUrl')?.setErrors(null);

    if (error === "CODE_EXIST") {
      this.editForm.get('code')?.setErrors({ codeExists: true });
    } else if (error === "NAME_EXIST") {
      this.editForm.get('name')?.setErrors({ nameExists: true });
    } else if (error === "MAPURL_EXIST") {
      this.editForm.get('mapUrl')?.setErrors({ mapUrlExists: true });
    } else {
      this.toastr.error("Error desconocido");
    }
  }
}
