import { Component } from '@angular/core';
import { FormBuilder, FormGroup, Validators } from '@angular/forms';
import { ToastrService } from 'ngx-toastr';
import { TerritoryService } from '../../shared/territory.service';
import { NgxSpinnerService } from 'ngx-spinner';

@Component({
  selector: 'generate-report',
  templateUrl: './generate-report.component.html',
})
export class GenerateReportComponent {
  generateReportForm: FormGroup;


  constructor(private formBuilder: FormBuilder, private toastr: ToastrService, private territoryService: TerritoryService, private spinner: NgxSpinnerService) {

    const currentDate = new Date();
    const formattedDate = this.formatDate(currentDate);

    this.generateReportForm = this.formBuilder.group({
      startDate: [formattedDate, Validators.required],
      endDate: [formattedDate, Validators.required],
    });

  }

  private formatDate(date: Date): string {
    const year = date.getFullYear();
    const month = ('0' + (date.getMonth() + 1)).slice(-2);
    const day = ('0' + date.getDate()).slice(-2);

    return `${year}-${month}-${day}`;
  }

  get f() { return this.generateReportForm.controls; }


  generarYDescargarExcel() {

    if (!this.generateReportForm.invalid) {

      this.spinner.show();

      this.territoryService.generateExcel(this.f['startDate'].value, this.f['endDate'].value).subscribe((data: Blob) => {
        const blob = new Blob([data], { type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' });
        const link = document.createElement('a');
        link.href = window.URL.createObjectURL(blob);
        link.download = 'TerritoryTransactions.xlsx';
        link.click();
        this.spinner.hide();
      });

    }

  }

}
