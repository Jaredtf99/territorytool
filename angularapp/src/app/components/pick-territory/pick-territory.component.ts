import { Component, ViewChild, AfterViewInit } from '@angular/core';
import { FormBuilder, FormGroup, Validators } from '@angular/forms';
import { ToastrService } from 'ngx-toastr';
import { TerritoryService } from '../../shared/territory.service';
import { NgxSpinnerService } from 'ngx-spinner';
import { Territory } from '../../classes/Territory';
import { Observable, Subject, catchError, concat, distinctUntilChanged, of, switchMap, tap } from 'rxjs';

@Component({
  selector: 'pick-territory',
  templateUrl: './pick-territory.component.html',
})
export class PickTerritoryComponent implements AfterViewInit {
  pickTerritoryForm: FormGroup;
  submitted = false;

  territories$!: Observable<Territory[]>;
  territoriesLoading = false;
  territoriesInput$ = new Subject<string>();
  selectedTerritory: Territory | undefined;


  constructor(private formBuilder: FormBuilder, private toastr: ToastrService, private territoryService: TerritoryService, private spinner: NgxSpinnerService) {

    const currentDate = new Date();
    const formattedDate = this.formatDate(currentDate);

    this.pickTerritoryForm = this.formBuilder.group({
      selectedTerritory: ['', Validators.required],
      customDate: [false, Validators.required],
      date: [formattedDate],
    });

  }

  private formatDate(date: Date): string {
    const year = date.getFullYear();
    const month = ('0' + (date.getMonth() + 1)).slice(-2);
    const day = ('0' + date.getDate()).slice(-2);

    return `${year}-${month}-${day}`;
  }

  ngAfterViewInit() {

    this.loadTerritories();

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

      let customDate = this.f['date'].value;

      if (this.f['customDate'].value) {
        customDate += `T${currentDate.getHours()}:${currentDate.getMinutes()}`;
      }

      this.territoryService.pickTerritory(this.f['selectedTerritory'].value, this.f['customDate'].value, customDate).subscribe({
        next: resp => {
          this.spinner.hide();
          this.toastr.success('Territorio recogido');
          this.pickTerritoryForm.reset();
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
