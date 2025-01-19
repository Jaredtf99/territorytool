import { Component, ElementRef, EventEmitter, Input, Output } from '@angular/core';
import { AbstractControl, FormBuilder, FormGroup, ValidationErrors, Validators } from '@angular/forms';
import { ToastrService } from 'ngx-toastr';
import { NgxSpinnerService } from "ngx-spinner";
import { TerritoryTransactionService } from 'src/app/services/territory-transaction.service';
import { TerritoryTransaction } from 'src/app/classes/territory-transaction.model';
import { Observable, Subject, catchError, concat, distinctUntilChanged, of, switchMap, tap } from 'rxjs';
import { PersonService } from 'src/app/shared/person.service';

declare var $: any;

@Component({
  selector: 'edit-transaction-modal',
  templateUrl: './edit-transaction-modal.component.html'
})
export class EditTransactionModalComponent {

  @Input() transactionId!: number;
  @Output() transactionUpdated: EventEmitter<void> = new EventEmitter<void>();

  editForm: FormGroup;

  persons$!: Observable<any[]>;
  personsLoading = false;
  personsInput$ = new Subject<string>();

  constructor(
    private fb: FormBuilder,
    private personService: PersonService,
    private toastr: ToastrService,
    private spinner: NgxSpinnerService,
    public territoryTransactionService: TerritoryTransactionService
  ) {
    this.editForm = this.fb.group({
      person: [null, Validators.required],
      givenDate: ['', Validators.required],
      pickedDate: ['']
    }, { validators: this.dateRangeValidator });
  }

  get f() { return this.editForm.controls; }

  openModal(): void {
    this.spinner.show();
    this.loadPersons();

    this.territoryTransactionService.getTransaction(this.transactionId).subscribe({
      next: res => {
        this.editForm.patchValue({
          person: { name: res.personName, id: res.personId },
          givenDate: this.formatDate(new Date(res.givenDateUtc)),
          pickedDate: res.pickedDateUtc ? this.formatDate(new Date(res.pickedDateUtc)) : null
        });

        $('#editTransaction').modal('show');
      },
      complete: () => {
        this.spinner.hide();
      }
    });
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

  editTransaction() {

    if (this.editForm.invalid) {
      return;
    }

    this.spinner.show();

    const transactionData = new TerritoryTransaction();
    transactionData.personId = this.editForm.value.person.id;
    transactionData.givenDateUtc = new Date(this.editForm.value.givenDate);
    transactionData.pickedDateUtc = this.editForm.value.pickedDate ? new Date(this.editForm.value.pickedDate) : undefined;

    this.territoryTransactionService.updateTransaction(this.transactionId, transactionData).subscribe({
      next: res => {
        this.transactionUpdated.emit();
        this.toastr.success('Transacción editada');
        $('#editTransaction').modal('hide');
      },
      error: err => {
        this.spinner.hide();
        this.handleError(err);
      },
      complete: () => {
        this.spinner.hide();
      }
    });
  }

  private handleError(error: any): void {
    if (error.error === "INVALID_DATES") {
      this.editForm.get('givenDate')?.setErrors({ invalidDates: true });
      this.editForm.get('pickedDate')?.setErrors({ invalidDates: true });
    } else if (error.error === "TERRITORY_ALREADY_IN_USE") {
      this.editForm.get('pickedDate')?.setErrors({ territoryInUse: true });
    } else {
      this.toastr.error("Error desconocido");
    }
  }

   // Validador personalizado para el rango de fechas
   dateRangeValidator(control: AbstractControl): ValidationErrors | null {
    const startDate = control.get('givenDate')?.value;
    const endDate = control.get('pickedDate')?.value;

    if (startDate && endDate && new Date(startDate) > new Date(endDate)) {
      return { dateRange: true };
    }
    return null;
  }
  
  private formatDate(date: Date): string {
    const year = date.getFullYear();
    const month = ('0' + (date.getMonth() + 1)).slice(-2);
    const day = ('0' + date.getDate()).slice(-2);
    const hours = ('0' + date.getHours()).slice(-2);
    const minutes = ('0' + date.getMinutes()).slice(-2);

    return `${year}-${month}-${day}T${hours}:${minutes}`;
  }
}
