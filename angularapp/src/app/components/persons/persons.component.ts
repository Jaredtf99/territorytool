import { Component, OnInit, Inject } from '@angular/core';
import { UserService } from '../../shared/user.service';
import { ToastrService } from 'ngx-toastr';
import { PersonService } from '../../shared/person.service';
import { NgxSpinnerService } from "ngx-spinner";

declare var $: any;

@Component({
  selector: 'app-persons',
  templateUrl: './persons.component.html',
  styleUrls: ['./persons.component.css']
})
export class PersonsComponent {

  persons: any[] = [];
  canDelete = false;
  public personNameToDelete = '';

  constructor(public userService: UserService, private toastr: ToastrService, private personService: PersonService, private spinner: NgxSpinnerService) {

    this.canDelete = userService.isAdmin() || userService.isSuperAdmin();
    this.getPersons();
  }

  getPersons() {

    this.spinner.show();

    this.personService.getAllPersons()
      .subscribe({
        next: resp => {
          this.persons = resp;
        },
        error: err => {
          console.error(err);
        },
        complete: () => {
          this.spinner.hide();
        }
      });

  }

  deletePerson() {
    this.spinner.show();

    $('#deletePerson').modal('hide');

    this.personService.deletePerson(this.personNameToDelete).subscribe(
      {
        next: resp => {
          this.getPersons();
          this.toastr.success('Hermano eliminado');
        },
        error: err => {
          this.toastr.error("Error desconocido");
        },
        complete: () => {
          this.spinner.hide();
        }
      });

  }


}
