import { Component, ViewChild, AfterViewInit } from '@angular/core';
import { FormBuilder, FormGroup, Validators, AbstractControl, ValidatorFn, ValidationErrors } from '@angular/forms';
import { ToastrService } from 'ngx-toastr';
import { TerritoryService } from '../../shared/territory.service';
import { NgxSpinnerService } from 'ngx-spinner';
import { Territory } from '../../classes/Territory';
import { Observable, Subject, catchError, concat, distinctUntilChanged, of, switchMap, tap } from 'rxjs';
import { NgxScannerQrcodeComponent, ScannerQRCodeConfig, ScannerQRCodeResult } from 'ngx-scanner-qrcode';
import { AppService } from '../../shared/app.service';
import { ActivatedRoute } from '@angular/router';

declare var $: any;

@Component({
  selector: 'pick-territory',
  templateUrl: './pick-territory.component.html',
})
export class PickTerritoryComponent implements AfterViewInit {
  pickTerritoryForm!: FormGroup;
  submitted = false;

  territories$!: Observable<Territory[]>;
  territoriesLoading = false;
  territoriesInput$ = new Subject<string>();
  selectedTerritory: Territory | undefined;

  @ViewChild('action') action!: NgxScannerQrcodeComponent;

  public config: ScannerQRCodeConfig = {
    isBeep: false,
    constraints: {
      video: {
        width: window.innerWidth
      },
    },
  };


  constructor(
    private formBuilder: FormBuilder,
    private toastr: ToastrService,
    private territoryService: TerritoryService,
    private spinner: NgxSpinnerService,
    private appService: AppService,
    private route: ActivatedRoute
  ) {

    this.resetTerritoryForm();
    this.loadTerritories();

    this.route.params.subscribe(params => {
      if (params['territoryCode']) {
        this.spinner.show();
        this.territoryService.getTerritoryByCode(params['territoryCode']).subscribe({
          next: (territory) => {
            this.selectedTerritory = territory;
            this.pickTerritoryForm.patchValue({
              selectedTerritory: territory
            });
            this.spinner.hide();
          },
          error: (err) => {
            this.spinner.hide();
            this.toastr.error('Error cargando el territorio');
          }
        });
      }
    });

  }

  onTerritorySelect(event: any) {
    if (event) {
      this.territoryService.getTerritoryByCode(event.code).subscribe({
        next: (territory) => {
          this.selectedTerritory = territory;
          this.pickTerritoryForm.patchValue({
            selectedTerritory: territory
          });
        }
      });
    }
  }

  private resetTerritoryForm() {
    const currentDate = new Date();
    const formattedDate = this.formatDate(currentDate);

    this.pickTerritoryForm = this.formBuilder.group({
      selectedTerritory: ['', Validators.required],
      customDate: [false, Validators.required],
      date: [formattedDate]
    });
  
    // Apply validators based on initial customDate value
    const dateControl = this.pickTerritoryForm.get('date');
    if (this.pickTerritoryForm.get('customDate')?.value) {
      dateControl?.setValidators([Validators.required, this.dateValidator()]);
      dateControl?.updateValueAndValidity();
    }

    this.appService.clearXButtonFromNgSelect("pickTerritoryNgSelectTerritories");
    this.loadTerritories();

        // Suscribirse a los cambios de customDate para actualizar los validadores de date
    this.pickTerritoryForm.get('customDate')?.valueChanges.subscribe((customDate: boolean) => {
      const dateControl = this.pickTerritoryForm.get('date');
      if (customDate) {
        dateControl?.setValidators([Validators.required, this.dateValidator()]);
      } else {
        dateControl?.clearValidators();
      }
      dateControl?.updateValueAndValidity();
    });
    
    
  }

  private dateValidator(): ValidatorFn {
    return (control: AbstractControl): ValidationErrors | null => {
      if (!this.pickTerritoryForm?.get('customDate')?.value) {
        return null;
      }

      const date = new Date(control.value);
        const now = new Date();

        // Si hay un territorio seleccionado, validar contra su fecha de entrega
        const territory = this.pickTerritoryForm?.get('selectedTerritory')?.value as Territory;
        if (territory && territory.givenDateUtc) {
          const givenDate = new Date(territory.givenDateUtc);
          if (date < givenDate) {
            return { beforeGivenDate: true };
          }
        }

        return null;
    };
  }

  private formatDate(date: Date): string {
    const year = date.getFullYear();
    const month = ('0' + (date.getMonth() + 1)).slice(-2);
    const day = ('0' + date.getDate()).slice(-2);
    const hours = ('0' + date.getHours()).slice(-2);
    const minutes = ('0' + date.getMinutes()).slice(-2);

    return `${year}-${month}-${day}T${hours}:${minutes}`;
  }


  ngAfterViewInit() {

    this.loadTerritories();

    const modalElement = document.querySelector('#modalScanner');

    modalElement!.addEventListener('hidden.bs.modal', () => {
      this.stopQrScanner();
    });

  }

  get f() { return this.pickTerritoryForm.controls; }


  private loadTerritories() {
    this.territories$ =
      this.territoriesInput$.pipe(
        distinctUntilChanged(),
        tap(() => this.territoriesLoading = true),
        switchMap(term => this.territoryService.searchGivenTerritories(term).pipe(
          catchError(() => of([])), // empty list on error
          tap(() => this.territoriesLoading = false)
        ))

      );
  }

  pickTerritory() {
    this.submitted = true;

    if (!this.pickTerritoryForm.invalid) {

      this.spinner.show();
      const currentDate = new Date();

      let customDate = this.f['date']
      ? new Date(this.f['date'].value)
      : undefined;

      this.territoryService.pickTerritory(this.f['selectedTerritory'].value.code, this.f['customDate'].value, customDate).subscribe({
        next: resp => {
          this.spinner.hide();
          this.toastr.success('Territorio recogido');
          this.resetTerritoryForm();
          this.submitted = false;
        },
        error: err => {
          this.spinner.hide();
          this.toastr.error('Error inesperado');
        }
      });
    }

  }

  public onEvent(e: ScannerQRCodeResult[], action?: any): void {

    this.territoryService.getTerritoryByMapUrl(e[0].value).subscribe({
      next: resp => {
        this.selectedTerritory = resp;
      },
      error: err => {
        this.toastr.error('Error inesperado');
      }
    });

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
