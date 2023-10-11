import { Component, OnInit } from '@angular/core';
import { UserService } from '../../shared/user.service';
import { ToastrService } from 'ngx-toastr';
import { NgxSpinnerService } from "ngx-spinner";

@Component({
  selector: 'app-user-configuration',
  templateUrl: './user-configuration.component.html',
  styleUrls: ['./user-configuration.component.css']
})
export class UserConfigurationComponent implements OnInit {

  constructor(public userService: UserService, private toastr: ToastrService, private spinner: NgxSpinnerService) { }

  ngOnInit() {
  }

  changePassword() {
    this.spinner.show();

    this.userService.changePassword().subscribe(
      (res: any) => {
        this.spinner.hide();
        this.userService.formModel.reset();
        this.toastr.success("Contraseña cambiada");
      },
      err => {
        this.spinner.hide();
        err.error.split(',').forEach((error: string) => {
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
