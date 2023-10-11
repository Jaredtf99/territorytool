import { Component, OnInit, Inject } from '@angular/core';
import { HttpClient } from '@angular/common/http';
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

  constructor(public http: HttpClient, @Inject('BASE_URL') public baseUrl: string, public userService: UserService, private toastr: ToastrService, private personService: PersonService, private spinner: NgxSpinnerService) {

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

    let formData = new FormData();
    formData.append('name', this.personNameToDelete.toString());
    $('#deletePerson').modal('hide');

    this.http.post(this.baseUrl + 'api/SampleData/DeletePerson', formData).subscribe(() => {
      this.spinner.hide();
      this.getPersons();
      this.toastr.success('Hermano eliminado');
    }, error => {
      this.spinner.hide();
      this.toastr.error("Error desconocido");
      console.error(error.error);
    });

  }


}
