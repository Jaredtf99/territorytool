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
      mapUrl: [this.territoryInfo.mapUrl, Validators.required]
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
      formValue.code
    ).subscribe({
      next: res => {
        $('#editTerritory').modal('hide');
        this.territoryUpdated.emit();
        this.spinner.hide();
        this.toastr.success('Territorio editado');
      },
      error: err => {
        this.spinner.hide();
        this.handleEditError(err);
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
