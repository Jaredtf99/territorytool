import { Component, Inject, ChangeDetectorRef, OnInit, ViewContainerRef, ViewChild, AfterViewInit } from '@angular/core';
import { FormBuilder, FormGroup, Validators } from '@angular/forms';
import { ToastrService } from 'ngx-toastr';
import { NgxScannerQrcodeComponent, ScannerQRCodeConfig, ScannerQRCodeResult } from 'ngx-scanner-qrcode';
import { TerritoryService } from '../../shared/territory.service';
import { NgxSpinnerService } from 'ngx-spinner';

declare var $: any;
let qrCodeScanner = this;

@Component({
  selector: 'add-territory',
  templateUrl: './add-territory.component.html',
  styleUrls: ['./add-territory.component.css']
})
export class AddTerritoryComponent implements AfterViewInit {
  addTerritoryForm: FormGroup;
  @ViewChild('action') action!: NgxScannerQrcodeComponent;

  public config: ScannerQRCodeConfig = {
    isBeep: false,
    constraints: {
      video: {
        width: window.innerWidth
      },
    },
  };


  constructor(private formBuilder: FormBuilder, private toastr: ToastrService, private territoryService: TerritoryService, private spinner: NgxSpinnerService) {
    this.addTerritoryForm = this.formBuilder.group({
      code: ['', Validators.required],
      name: ['', Validators.required],
      mapUrl: ['', Validators.required]
    });

  }

  ngAfterViewInit() {
    const modalElement = document.querySelector('#modalScanner');

    modalElement!.addEventListener('hidden.bs.modal', () => {
      this.stopQrScanner();
    });

  }

  get f() { return this.addTerritoryForm.controls; }


  addTerritory() {

    if (!this.addTerritoryForm.invalid) {

      this.spinner.show();

      this.territoryService.addTerritory(this.f['mapUrl'].value, this.f['name'].value, this.f['code'].value).subscribe({
        next: resp => {
          this.spinner.hide();
          this.toastr.success('Territorio guardado');
          this.addTerritoryForm.reset();
        },
        error: err => {
          this.spinner.hide();
          this.handleAddError(err);
        }
      });
    }

  }

  private handleAddError(err: any): void {
    const error = err.error;

    // Limpiar errores previos
    this.addTerritoryForm.get('name')?.setErrors(null);
    this.addTerritoryForm.get('code')?.setErrors(null);
    this.addTerritoryForm.get('mapUrl')?.setErrors(null);

    if (error === "CODE_EXIST") {
      this.addTerritoryForm.get('code')?.setErrors({ codeExists: true });
    } else if (error === "NAME_EXIST") {
      this.addTerritoryForm.get('name')?.setErrors({ nameExists: true });
    } else if (error === "MAPURL_EXIST") {
      this.addTerritoryForm.get('mapUrl')?.setErrors({ mapUrlExists: true });
    } else {
      this.toastr.error("Error desconocido");
    }
  }

  public onEvent(e: ScannerQRCodeResult[], action?: any): void {
    this.f['mapUrl'].setValue(e[0].value);
    $('#modalScanner').modal('hide');
  }


  startQrScanner() {
    const fn = 'start';

    const playDeviceFacingBack = (devices: any[]) => {
      const device = devices.find(f => (/back|rear|environment/gi.test(f.label)));
      const indexToChoose = devices.length > 1 ? 1 : 0;
      this.action.playDevice(device ? device.deviceId : devices[indexToChoose].deviceId);
    }

    this.action[fn](playDeviceFacingBack).subscribe((r: any) => alert);

  }

  stopQrScanner() {
    const fn = 'stop';

    this.action[fn]().subscribe((r: any) => alert);
  }


}
