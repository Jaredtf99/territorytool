import { Component, OnInit, Inject } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { UserService } from '../../shared/user.service';
import { RoleType } from '../../enums/RoleType';
import { User } from '../../classes/User';
import { ToastrService } from 'ngx-toastr';
import { NgxSpinnerService } from "ngx-spinner";
import { CellComponent, TabulatorFull as Tabulator } from 'tabulator-tables';

declare var $: any;

@Component({
  selector: 'app-users',
  templateUrl: './users.component.html',
  styleUrls: ['./users.component.css']
})
export class UsersComponent implements OnInit {

  role: RoleType;
  public users!: User[];
  public userToEdit: User = new User();
  public idUserToDelete = '';
  public rolesCanIChange: string[] = [];
  public defaultRoleIndex = 0;

  constructor(public http: HttpClient, @Inject('BASE_URL') public baseUrl: string, public userService: UserService, private toastr: ToastrService, private spinner: NgxSpinnerService) {

    this.role = userService.getRole();
    this.spinner.show();

    this.setRolesCanIChange();

    this.getUsersData();
  }
  editIcon = function () {
    return "<i class='fa fa-pen-to-square'></i>";
  };

  deleteIcon = function () {
    return "<i class='fa fa-trash-can'></i>";
  };

  getUsersData() {

    this.userService.getAllUsers().subscribe({
      next: res => {
        this.spinner.hide();
        this.users = res;
        this.buildTabulatorTable();
      },
      error: err => {
        this.spinner.hide();
        console.error(err);
      }
    });

  }

  buildTabulatorTable() {
    new Tabulator("#users_table", {
      data: this.users,
      layout: "fitColumns",
      maxHeight: "100%",
      columns: [
        {
          title: "",
          formatter: this.editIcon,
          width: 40,
          hozAlign: "center",
          headerSort: false,
          cellClick: (e, cell) => this.openEditModal(cell.getRow().getData().UserID)
        },
        {
          title: "", formatter: this.deleteIcon, width: 40, hozAlign: "center", headerSort: false,
          cellClick: (e, cell) => this.openDeleteUserModal(cell.getRow().getData().UserID)
        },
        { title: "ID", field: "UserID", headerFilter: "input" },
        { title: "Name", field: "UserName", headerFilter: "input" },
        { title: "Role", field: "Role", headerFilter: "input" },
      ],
    });


  }

  canConfigurate(userRoleToConfigurate: string) {
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

  setRolesCanIChange() {

    this.rolesCanIChange = [];

    switch (this.role) {
      case RoleType.SUPERADMIN:
        this.rolesCanIChange = [RoleType[RoleType.ADMIN], RoleType[RoleType.USER]];
        break;
      case RoleType.ADMIN:
        this.rolesCanIChange = [RoleType[RoleType.USER]];
    }

  }

  openEditModal(idToEdit: any) {
    $('#editUser').modal('show');
    Object.assign(this.userToEdit, this.users.filter(user => user.UserID === idToEdit)[0]);
  }

  selectedRoleEventHandler(roleIndex: number) {
    this.userToEdit.Role = this.rolesCanIChange[roleIndex];
  }

  editUser() {
    this.spinner.show();

    let uEdit = this.userToEdit;

    this.userService.editUser(uEdit.UserID!, uEdit.UserName!, uEdit.Role!).subscribe({
      next: res => {
        this.toastr.success('Usuario editado');
        Object.assign(this.users.filter(user => user.UserID === this.userToEdit.UserID)[0], this.userToEdit);

        $('#editUser').modal('hide');
        this.spinner.hide();
      },
      error: error => {
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

        this.spinner.hide();
      }
    });
  }

  openDeleteUserModal(idToDelete: string) {
    $('#deleteUser').modal('show');
    this.idUserToDelete = idToDelete;
  }

  deleteUser() {
    this.spinner.show();

    $('#deleteUser').modal('hide');

    this.userService.deleteUser(this.idUserToDelete).subscribe({
      next: res => {
        this.toastr.success('Usuario eliminado');
        this.getUsersData();
      },
      error: error => {
        this.spinner.hide();
        this.toastr.error("Error desconocido");
      }
    });

  }


  ngOnInit() {
  }

}
