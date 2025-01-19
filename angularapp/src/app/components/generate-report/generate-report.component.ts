import { Component } from '@angular/core';
import { FormBuilder, FormGroup, Validators, AbstractControl, ValidationErrors } from '@angular/forms';
import { ToastrService } from 'ngx-toastr';
import { TerritoryService } from '../../shared/territory.service';
import { NgxSpinnerService } from 'ngx-spinner';

@Component({
  selector: 'generate-report',
  templateUrl: './generate-report.component.html',
})
export class GenerateReportComponent {
  generateReportForm: FormGroup;

  constructor(
    private formBuilder: FormBuilder, 
    private toastr: ToastrService, 
    private territoryService: TerritoryService, 
    private spinner: NgxSpinnerService
  ) {
    const currentDate = new Date();
    const formattedDate = this.formatDate(currentDate, false);

    this.generateReportForm = this.formBuilder.group({
      startDate: [formattedDate, Validators.required],
      endDate: [formattedDate, Validators.required],
    }, { validators: this.dateRangeValidator });
  }

  // Validador personalizado para el rango de fechas
  dateRangeValidator(control: AbstractControl): ValidationErrors | null {
    const startDate = control.get('startDate')?.value;
    const endDate = control.get('endDate')?.value;

    if (startDate && endDate && new Date(startDate) > new Date(endDate)) {
      return { dateRange: true };
    }
    return null;
  }

  private formatDate(date: Date, withTime: boolean): string {
    const year = date.getFullYear();
    const month = ('0' + (date.getMonth() + 1)).slice(-2);
    const day = ('0' + date.getDate()).slice(-2);
    const hours = ('0' + date.getHours()).slice(-2);
    const minutes = ('0' + date.getMinutes()).slice(-2);

    let dateformatted = `${year}-${month}-${day}`;
    
    if (withTime) {
      dateformatted += `T${hours}:${minutes}`;
    }

    return dateformatted;
  }

  get f() { return this.generateReportForm.controls; }

  generarYDescargarExcel() {
    if (this.generateReportForm.invalid) {
      this.toastr.error('Por favor, corrige los errores en el formulario');
      return;
    }

    this.spinner.show();

    let startDate = new Date(`${this.f['startDate'].value}T00:00`);
    let endDate = new Date(`${this.f['endDate'].value}T00:00`);
    this.territoryService.generateExcel(startDate, endDate).subscribe((data: Blob) => {
      const blob = new Blob([data], { type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' });
      const link = document.createElement('a');
      link.href = window.URL.createObjectURL(blob);
      link.download = 'TerritoryTransactions.xlsx';
      link.click();
      this.spinner.hide();
    });
  }
}
