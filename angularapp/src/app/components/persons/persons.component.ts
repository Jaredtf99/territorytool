import { Component, OnInit, Inject } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Globals } from '../../globals';
import { UserService } from '../../shared/user.service';
import { ToastrService } from 'ngx-toastr';
import { PersonService } from '../../shared/person.service';

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

  constructor(public http: HttpClient, @Inject('BASE_URL') public baseUrl: string, private globals: Globals, public userService: UserService, private toastr: ToastrService, private personService: PersonService) {

    this.canDelete = userService.isAdmin() || userService.isSuperAdmin();
    this.getPersons();
  }

  getPersons() {

    this.globals.loading = true;

    this.personService.getAllPersons()
      .subscribe({
        next: resp => {
          this.globals.loading = false;
          this.persons = resp;
        },
        error: err => {
          this.globals.loading = false;
          console.error(err);
        }
      });

  }

  deletePerson() {
    this.globals.loading = true;

    let formData = new FormData();
    formData.append('name', this.personNameToDelete.toString());
    $('#deletePerson').modal('hide');

    this.http.post(this.baseUrl + 'api/SampleData/DeletePerson', formData).subscribe(() => {
      this.getPersons();
      this.toastr.success('Hermano eliminado');
    }, error => {
      this.globals.loading = false;
      this.toastr.error("Error desconocido");
      console.error(error.error);
    });

  }


}
