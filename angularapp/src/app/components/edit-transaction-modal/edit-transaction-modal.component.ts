import { Component, ElementRef, EventEmitter, Input, Output,  } from '@angular/core';
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

  transactionInfo: TerritoryTransaction = new TerritoryTransaction(); 

  persons$!: Observable<any[]>;
  personsLoading = false;
  personsInput$ = new Subject<string>();
  selectedPerson!: any | null;

  givenDateFormatted: string | undefined;
  pickedDateFormatted: string | undefined;

  constructor(private personService: PersonService, private toastr: ToastrService, private spinner: NgxSpinnerService, public territoryTransactionService: TerritoryTransactionService) {
  }

  openModal(): void {
    this.spinner.show();
    this.loadPersons();

     this.territoryTransactionService.getTransaction(this.transactionId).subscribe(
      {
        next: res => {
          this.transactionInfo = res;
          this.selectedPerson = { name: res.personName, id: res.personId };

        this.givenDateFormatted = this.formatDate(new Date(this.transactionInfo.givenDateUtc));
        if (this.transactionInfo.pickedDateUtc) {
          this.pickedDateFormatted = this.formatDate(new Date(this.transactionInfo.pickedDateUtc));
        }

          $('#editTransaction').modal('show');
        },
        complete: () => {
          this.spinner.hide();
        }
      })
    
  }

  //TODO: Sacar esto a un componente, y utilizar el mismo en todas las pantallas. Lo mismo con el de territorios
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
    this.spinner.show();

    $('#editTransaction').modal('hide');

    this.transactionInfo.givenDateUtc = new Date(this.givenDateFormatted!)
    this.transactionInfo.pickedDateUtc = this.pickedDateFormatted
      ? new Date(this.pickedDateFormatted)
      : undefined;
      this.transactionInfo.personId = this.selectedPerson.id;

    this.territoryTransactionService.updateTransaction(this.transactionId, this.transactionInfo!).subscribe(
      {
        next: res => {
          this.transactionUpdated.emit();
          this.toastr.success('Transaccion editada');
        },
        error: err => {
          if (err.error === "CODE_EXIST")
            this.toastr.error("El código ya existe");
          else if (err.error === "NAME_EXIST")
            this.toastr.error("El nombre ya existe");
          else if (err.error === "MAPURL_EXIST")
            this.toastr.error("La URL del mapa ya existe");
          else {
            this.toastr.error("Error desconocido");
          }
        },
        complete: () => {
          this.spinner.hide();
        }
      }
    );
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
