import { Component, OnInit, Inject } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Globals } from '../../globals';
import { UserService } from '../../shared/user.service';
import { ToastrService } from 'ngx-toastr';

declare var $: any;

@Component({
  selector: 'app-persons',
  templateUrl: './persons.component.html',
  styleUrls: ['./persons.component.css']
})
export class PersonsComponent implements OnInit {

  persons: any[] = [];
  canDelete = false;
  public personNameToDelete = '';

  constructor(public http: HttpClient, @Inject('BASE_URL') public baseUrl: string, private globals: Globals, public userService: UserService, private toastr: ToastrService) {

    this.canDelete = userService.isAdmin() || userService.isSuperAdmin();
    this.getPersons();
  }

  ngOnInit() {
  }

  getPersons() {

    this.globals.loading = true;
    this.http.get<any[]>(this.baseUrl + 'api/SampleData/GetAllPersons').subscribe(result => {
      this.globals.loading = false;
      this.persons = result;
    }, error => {
      this.globals.loading = false;
      console.error(error);
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
