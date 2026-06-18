import { NgxScannerQrcodeComponent, ScannerQRCodeConfig, ScannerQRCodeResult } from 'ngx-scanner-qrcode';
import { Component, ViewChild, AfterViewInit } from '@angular/core';
import { FormBuilder, FormGroup, Validators, AbstractControl, ValidatorFn, ValidationErrors } from '@angular/forms';
import { ToastrService } from 'ngx-toastr';
import { TerritoryService } from '../../shared/territory.service';
import { NgxSpinnerService } from 'ngx-spinner';
import { Territory } from '../../classes/Territory';
import { Observable, Subject, catchError, concat, debounceTime, distinctUntilChanged, filter, of, switchMap, tap } from 'rxjs';
import { PersonService } from '../../shared/person.service';
import { AppService } from '../../shared/app.service';
import { TerritorySuggestion } from 'src/app/classes/TerritorySuggestion';
import { ActivatedRoute } from '@angular/router';


declare var $: any;

@Component({
  selector: 'change-territory',
  templateUrl: './change-territory.component.html',
  styleUrls: ['./change-territory.component.css']
})
export class ChangeTerritoryComponent implements AfterViewInit {
  giveTerritoryForm!: FormGroup;
  submitted = false;

  territories$!: Observable<Territory[]>;
  territoriesLoading = false;
  territoriesInput$ = new Subject<string>();
  selectedTerritory!: Territory | null;


  persons$!: Observable<any[]>;
  personsLoading = false;
  personsInput$ = new Subject<string>();
  selectedPerson!: any | null;

  territorySuggestions!: TerritorySuggestion[];
  loadingSuggestions = true;


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
    private personService: PersonService,
    private spinner: NgxSpinnerService,
    private appService: AppService,
    private route: ActivatedRoute
  ) {

    const currentDate = new Date();
    const formattedDate = this.formatDate(currentDate);

    this.giveTerritoryForm = this.formBuilder.group({
      selectedTerritory: ['', Validators.required],
      selectedPerson: ['', Validators.required],
      customDate: [false, Validators.required],
      date: [formattedDate]
    });

    // Apply validators based on initial customDate value
    const dateControl = this.giveTerritoryForm.get('date');
    if (this.giveTerritoryForm.get('customDate')?.value) {
      dateControl?.setValidators([Validators.required, this.dateValidator()]);
      dateControl?.updateValueAndValidity();
    }

    this.loadPersons();
    this.loadTerritories();

    this.route.params.subscribe(params => {
      if (params['territoryCode']) {
        this.spinner.show();
        this.territoryService.getTerritoryByCode(params['territoryCode']).subscribe({
          next: (territory) => {
            this.selectedTerritory = territory;
            this.giveTerritoryForm.patchValue({
              selectedTerritory: territory
            });
            this.loadTerritories();
            this.spinner.hide();
          },
          error: (err) => {
            this.spinner.hide();
            this.toastr.error('Error cargando el territorio');
          }
        });
      }
    });

    // Suscribirse a los cambios de customDate para actualizar los validadores de date
    this.giveTerritoryForm.get('customDate')?.valueChanges.subscribe((customDate: boolean) => {
      const dateControl = this.giveTerritoryForm.get('date');
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
      if (!this.giveTerritoryForm?.get('customDate')?.value) {
        return null;
      }

      const date = new Date(control.value);
      const now = new Date();
      
      // Si hay un territorio seleccionado, validar contra su última fecha de recogida
      const territory = this.giveTerritoryForm?.get('selectedTerritory')?.value as Territory;
      if (territory && territory.lastPickedDateUtc) {
        const lastPickedDate = new Date(territory.lastPickedDateUtc);
        if (date < lastPickedDate) {
          return { dateBeforeLastPicked: true };
        }
      }

      return null;
    };
  }

  private resetTerritoryForm() {
    const currentDate = new Date();
    const formattedDate = this.formatDate(currentDate);

    this.giveTerritoryForm = this.formBuilder.group({
      selectedTerritory: [null, Validators.required],
      selectedPerson: [null, Validators.required],
      customDate: [false, Validators.required],
      date: [formattedDate]
    });

    // Apply validators based on initial customDate value
    const dateControl = this.giveTerritoryForm.get('date');
    if (this.giveTerritoryForm.get('customDate')?.value) {
      dateControl?.setValidators([Validators.required, this.dateValidator()]);
      dateControl?.updateValueAndValidity();
    }

    this.appService.clearXButtonFromNgSelect("changeTerritoryNgSelectTerritories");
    this.appService.clearXButtonFromNgSelect("changeTerritoryNgSelectPerson");

    this.loadTerritories();
    this.loadPersons();

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
    this.loadPersons();
    this.loadTerritorySuggestions();

    const modalElement = document.querySelector('#modalScanner');

    modalElement!.addEventListener('hidden.bs.modal', () => {
      this.stopQrScanner();
    });

  }

  get f() { return this.giveTerritoryForm.controls; }


  private loadTerritories() {
    // Seed the items with the currently selected territory so ng-select can
    // render it (e.g. a clicked suggestion) before any search has run.
    this.territories$ = concat(
      of(this.selectedTerritory ? [this.selectedTerritory] : []),
      this.territoriesInput$.pipe(
        filter((term): term is string => (term?.length ?? 0) >= 2),
        debounceTime(250),
        distinctUntilChanged(),
        tap(() => this.territoriesLoading = true),
        switchMap(term => this.territoryService.searchFreeTerritories(term, 3).pipe(
          catchError(() => of([])), // empty list on error
          tap(() => this.territoriesLoading = false)
        ))
      )
    );
  }

  onTerritorySelect(event: any) {
    if (event) {
      this.territoryService.getTerritoryByCode(event.code).subscribe({
        next: (territory) => {
          this.selectedTerritory = territory;
          this.giveTerritoryForm.patchValue({
            selectedTerritory: territory
          });
          this.loadTerritories();
        }
      });
    }
  }

  private loadPersons() {
    this.persons$ =
      this.personsInput$.pipe(
        filter((term): term is string => (term?.length ?? 0) >= 3),
        debounceTime(250),
        distinctUntilChanged(),
        tap(() => this.personsLoading = true),
        switchMap(term => this.personService.searchPersons(term, 3).pipe(
          catchError(() => of([])), // empty list on error
          tap(() => this.personsLoading = false)
        ))

      );
  }

  giveTerritory() {
    this.submitted = true;

    if (!this.giveTerritoryForm.invalid) {

      this.spinner.show();

      let customDate = this.f['date']
      ? new Date(this.f['date'].value)
      : undefined;

      this.territoryService.giveTerritory(this.f['selectedTerritory'].value.code, this.f['selectedPerson'].value.name, this.f['customDate'].value, customDate).subscribe({
        next: resp => {
          this.spinner.hide();
          this.toastr.success('Territorio entregado');
          this.resetTerritoryForm();
          this.submitted = false;
          this.loadTerritories();
          this.loadPersons();
          this.loadTerritorySuggestions();      
        },
        error: err => {
          this.spinner.hide();
          this.toastr.error('Error inesperado');
        }
      });
    }

  }

  loadTerritorySuggestions() {
    this.loadingSuggestions = true;
    
    this.territoryService.getTerritorySuggestions().subscribe({
      next: resp => {
        this.territorySuggestions = resp.sort((a, b) => {
          if (!a.lastPickedDate && b.lastPickedDate) return -1;
          if (a.lastPickedDate && !b.lastPickedDate) return 1;
          if (!a.lastPickedDate && !b.lastPickedDate) return 0;
          return new Date(a.lastPickedDate!).getTime() - new Date(b.lastPickedDate!).getTime();
        });
        this.loadingSuggestions = false;
      },
      error: err => {
        this.loadingSuggestions = false;
      }
    });
  }



  public onEvent(e: ScannerQRCodeResult[], action?: any): void {

    this.territoryService.getTerritoryByMapUrl(e[0].value).subscribe({
      next: resp => {
        this.selectedTerritory = resp;
        this.giveTerritoryForm.patchValue({ selectedTerritory: resp });
        this.loadTerritories();
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

  selectSuggestedTerritory(territory: TerritorySuggestion) {
    this.selectedTerritory = {
      id: territory.id,
      code: territory.code,
      name: territory.name,
      lastPickedDateUtc: territory.lastPickedDate,
      imgUrl: territory.imgUrl
    } as Territory;

    this.giveTerritoryForm.patchValue({
      selectedTerritory: this.selectedTerritory
    });
    // Reseed the ng-select items so the chosen suggestion is displayed.
    this.loadTerritories();
  }

}
