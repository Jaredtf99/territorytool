import { Component, ViewChild, AfterViewInit } from '@angular/core';
import { FormBuilder, FormGroup, Validators } from '@angular/forms';
import { ToastrService } from 'ngx-toastr';
import { TerritoryService } from '../../shared/territory.service';
import { NgxSpinnerService } from 'ngx-spinner';
import { Territory } from '../../classes/Territory';
import { Observable, Subject, catchError, concat, distinctUntilChanged, of, switchMap, tap } from 'rxjs';
import { PersonService } from '../../shared/person.service';

@Component({
  selector: 'change-territory',
  templateUrl: './change-territory.component.html',
  styleUrls: ['./change-territory.component.css']
})
export class ChangeTerritoryComponent implements AfterViewInit {
  giveTerritoryForm: FormGroup;
  submitted = false;

  territories$!: Observable<Territory[]>;
  territoriesLoading = false;
  territoriesInput$ = new Subject<string>();
  selectedTerritory: Territory | undefined;


  persons$!: Observable<any[]>;
  personsLoading = false;
  personsInput$ = new Subject<string>();
  selectedPerson: any | undefined;


  constructor(private formBuilder: FormBuilder, private toastr: ToastrService, private territoryService: TerritoryService, private personService: PersonService, private spinner: NgxSpinnerService) {

    const currentDate = new Date();
    const formattedDate = this.formatDate(currentDate);

    this.giveTerritoryForm = this.formBuilder.group({
      selectedTerritory: ['', Validators.required],
      selectedPerson: ['', Validators.required],
      customDate: [false, Validators.required],
      date: [formattedDate],
    });

  }

  private formatDate(date: Date): string {
    const year = date.getFullYear();
    const month = ('0' + (date.getMonth() + 1)).slice(-2);
    const day = ('0' + date.getDate()).slice(-2);
    const hours = ('0' + date.getHours()).slice(-2);
    const minutes = ('0' + date.getMinutes()).slice(-2);

    return `${year}-${month}-${day}`;
  }

  ngAfterViewInit() {

    this.loadTerritories();
    this.loadPersons();

  }

  get f() { return this.giveTerritoryForm.controls; }


  private loadTerritories() {
    this.territories$ = 
      this.territoriesInput$.pipe(
        distinctUntilChanged(),
        tap(() => this.territoriesLoading = true),
        switchMap(term => this.territoryService.searchFreeTerritories(term).pipe(
          catchError(() => of([])), // empty list on error
          tap(() => this.territoriesLoading = false)
        ))
      
    );
  }

  private loadPersons() {
    this.persons$ =
      this.personsInput$.pipe(
        distinctUntilChanged(),
        tap(() => this.personsLoading = true),
        switchMap(term => this.personService.searchPersons(term).pipe(
          catchError(() => of([])), // empty list on error
          tap(() => this.personsLoading = false)
        ))

      );
  }

  giveTerritory() {
    this.submitted = true;

    if (!this.giveTerritoryForm.invalid) {

      this.spinner.show();
      const currentDate = new Date();

      let customDate = this.f['date'].value;

      if (this.f['customDate'].value) {
        customDate += `T${currentDate.getHours()}:${currentDate.getMinutes()}`;
      }

      this.territoryService.giveTerritory(this.f['selectedTerritory'].value, this.f['selectedPerson'].value, this.f['customDate'].value, customDate).subscribe({
        next: resp => {
          this.spinner.hide();
          this.toastr.success('Territorio entregado');
          this.giveTerritoryForm.reset();
          this.submitted = false;
        },
        error: err => {
          this.spinner.hide();
          this.toastr.error('Error inesperado');
        }
      });
    }

  }



}
