import { Component, OnInit, Inject } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Globals } from '../../globals';
import { UserService } from '../../shared/user.service';
import { RoleType } from '../../enums/RoleType';
import { User } from '../../classes/User';
import { ToastrService } from 'ngx-toastr';

declare var $: any;

@Component({
  selector: 'app-users',
  templateUrl: './users.component.html',
  styleUrls: ['./users.component.css']
})
export class UsersComponent implements OnInit {

  role: RoleType;
  public users: User[];
  public userToEdit: User = new User();
  public idUserToDelete = '';
  public rolesCanIChange: string[] = [];
  public defaultRoleIndex = 0;

  constructor(public http: HttpClient, @Inject('BASE_URL') public baseUrl: string, private globals: Globals, public userService: UserService, private toastr: ToastrService) {

    this.role = userService.getRole();
    this.globals.loading = true;

    this.setRolesCanIChange();

    http.get<User[]>(baseUrl + 'api/user/get-users').subscribe(result => {
      this.globals.loading = false;
      this.users = result;
    }, error => {
      this.globals.loading = false;
      console.error(error);
    });

  }

  canConfigurate(userRoleToConfigurate: string)
  {
    let userRoleToConfigurateParsed = RoleType[userRoleToConfigurate as keyof typeof RoleType];

    switch (userRoleToConfigurateParsed) {
      case RoleType.SUPERADMIN:
        return false;
      case RoleType.ADMIN:
        return this.role === RoleType.SUPERADMIN;
      default:
        return true;
    }
  }

  setRolesCanIChange(){

    this.rolesCanIChange = [];

    switch (this.role) {
      case RoleType.SUPERADMIN:
        this.rolesCanIChange = [RoleType[RoleType.ADMIN], RoleType[RoleType.USER]];
        break;
    }

  }

  setDefaultRoleIndex() {
    let defaultRoleIndex = this.rolesCanIChange.indexOf(this.userToEdit.Role.toString());
    if (defaultRoleIndex === -1)
      defaultRoleIndex = 0;

      this.defaultRoleIndex = defaultRoleIndex;
  }

  openEditModal(idToEdit) {
    Object.assign(this.userToEdit, this.users.filter(user => user.UserID === idToEdit)[0]);
    this.setDefaultRoleIndex();
  }

  selectedRoleEventHandler(roleIndex)
  {
    this.userToEdit.Role = this.rolesCanIChange[roleIndex];
  }

  editTerritory() {
    this.globals.loading = true;

    let body = {
      userID: this.userToEdit.UserID,
      userName: this.userToEdit.UserName,
      role: RoleType[this.userToEdit.Role]
    };

    this.http.post(this.baseUrl + 'api/user/edit-user', body).subscribe(() => {
      this.globals.loading = false;
      this.toastr.success('Usuario editado');
      Object.assign(this.users.filter(user => user.UserID === this.userToEdit.UserID)[0], this.userToEdit);

      $('#editUser').modal('hide');
    }, error => {
      this.globals.loading = false;
        if (error.error === "INVALID_PARAMETERS")
        this.toastr.error("Datos invalidos, vuelva a intentarlo");
        else if (error.error === "USER_NOT_EXISTS")
        this.toastr.error("No hemos encontrado el usuario que quieres editar...");
        else if (error.error === "USERNAME_IN_USE")
        this.toastr.error("El nombre de usuario ya esta en uso");
      else {
        this.toastr.error("Error desconocido");
        console.error(error.error);
      }
    });
  }

  //assignIdToDelete(idToDelete) {
  //  this.idTerritoryToDelete = idToDelete;
  //}

  //deleteTerritory() {
  //  this.globals.loading = true;

  //  let formData = new FormData();
  //  formData.append('idToDelete', this.idTerritoryToDelete.toString());
  //  $('#deleteTerritory').modal('hide');

  //  this.http.post(this.baseUrl + 'api/SampleData/deleteTerritory', formData).subscribe(() => {
  //    this.globals.loading = false;
  //    this.toastr.success('Territorio eliminado');
  //    this.territories.splice(this.territories.indexOf(this.territoriesFiltered.filter(territory => territory.id === this.idTerritoryToDelete)[0]), 1);
  //    this.filter();
  //  }, error => {
  //    this.globals.loading = false;
  //    this.toastr.error("Error desconocido");
  //    console.error(error.error);
  //  });

  //}


  ngOnInit() {
  }

}
