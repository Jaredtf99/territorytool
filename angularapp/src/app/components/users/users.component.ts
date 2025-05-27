import { Component, OnInit, Inject } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { UserService } from '../../shared/user.service';
import { RoleType } from '../../enums/RoleType';
import { User } from '../../classes/User';
import { ToastrService } from 'ngx-toastr';
import { NgxSpinnerService } from "ngx-spinner";
import { CellComponent, TabulatorFull as Tabulator } from 'tabulator-tables';
import { FormBuilder, FormGroup, Validators } from '@angular/forms';

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
  public editForm: FormGroup;
  public canChangePassword = false;

  constructor(public http: HttpClient, @Inject('BASE_URL') public baseUrl: string, public userService: UserService, private toastr: ToastrService, private spinner: NgxSpinnerService, private fb: FormBuilder) {

    this.role = userService.getRole();
    this.spinner.show();

    this.setRolesCanIChange();

    this.editForm = this.fb.group({
      userName: ['', Validators.required],
      role: ['', Validators.required],
      newPassword: ['', Validators.minLength(8)]
    });

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
    const user = this.users.filter(user => user.UserID === idToEdit)[0];
    this.userToEdit = user;
    this.editForm.patchValue({
      userName: user.UserName,
      role: user.Role
    });
    this.editForm.get('newPassword')?.reset();

    const userRoleToEdit = RoleType[user.Role as keyof typeof RoleType];
    this.canChangePassword = false; // Default to false

    if (this.role === RoleType.SUPERADMIN && (userRoleToEdit === RoleType.ADMIN || userRoleToEdit === RoleType.USER)) {
      this.canChangePassword = true;
    } else if (this.role === RoleType.ADMIN && userRoleToEdit === RoleType.USER) {
      this.canChangePassword = true;
    }

  }

  selectedRoleEventHandler(roleIndex: number) {
    this.userToEdit.Role = this.rolesCanIChange[roleIndex];
  }

  editUser() {
    if (this.editForm.invalid) {
      return;
    }

    this.spinner.show();

    const formValue = this.editForm.value;
    this.userService.editUser(this.userToEdit.UserID!, formValue.userName, formValue.role).subscribe({
      next: res => {
        this.toastr.success('Usuario editado');
        Object.assign(this.users.filter(user => user.UserID === this.userToEdit.UserID)[0], this.userToEdit);

        $('#editUser').modal('hide');
        this.spinner.hide();
      },
      error: error => {
        this.handleEditError(error);
        this.spinner.hide();
      }
    });
  }

  private handleEditError(error: any): void {
    if (error.error === "USERNAME_IN_USE") {
      this.editForm.get('userName')?.setErrors({ usernameExists: true });
    } else {
      this.toastr.error("Error desconocido");
      console.error(error.error);
    }
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

  changePassword() {
    if (this.editForm.get('newPassword')?.invalid) {
      return;
    }

    this.spinner.show();
    const newPassword = this.editForm.get('newPassword')?.value;

    this.userService.changeUserPassword(this.userToEdit.UserID!, newPassword).subscribe({
      next: () => {
        this.toastr.success('Contraseña cambiada correctamente');
        $('#editUser').modal('hide');
        this.spinner.hide();
        this.editForm.get('newPassword')?.reset();
      },
      error: (error) => {
        this.toastr.error('Error al cambiar la contraseña');
        console.error(error);
        this.spinner.hide();
        this.editForm.get('newPassword')?.reset();
      }
    });
  }

}
