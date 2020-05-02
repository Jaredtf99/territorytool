import { Component, OnInit } from '@angular/core';
import { UserService } from '../shared/user.service';
import { ToastrService } from 'ngx-toastr';
import { Globals } from '../globals';

@Component({
  selector: 'app-user-configuration',
  templateUrl: './user-configuration.component.html',
  styleUrls: ['./user-configuration.component.css']
})
export class UserConfigurationComponent implements OnInit {

  constructor(public userService: UserService, private toastr: ToastrService, private globals: Globals) { }

  ngOnInit() {
  }

  changePassword() {
    this.globals.loading = true;

    this.userService.changePassword().subscribe(
      (res: any) => {
        this.globals.loading = false;
        this.userService.formModel.reset();
        this.toastr.success("Contraseña cambiada");
      },
      err => {
        this.globals.loading = false;
        err.error.split(',').forEach(error => {
          switch (error) {
            case 'PasswordMismatch':
              this.toastr.error("La contraseña no es correcta");
              break;
            case 'PasswordTooShort':
              this.toastr.error("La contraseña debe tener al menos 4 caracteres");
              break;
            default:
              this.toastr.error('Error cambiando la contraseña');
              console.log(err);
              break;
          }
        });
      }
    )
  }

}
