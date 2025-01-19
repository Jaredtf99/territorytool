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
  submitted = false;

  constructor(public userService: UserService, private toastr: ToastrService, private spinner: NgxSpinnerService) { }

  ngOnInit() {
  }

  changePassword() {
    this.submitted = true;

    if (this.userService.changePasswordForm.invalid) {
      return;
    }

    this.spinner.show();
    this.userService.changePassword().subscribe(
      {
        next: res => {
          this.spinner.hide();
          this.userService.changePasswordForm.reset();
          this.toastr.success("Contraseña cambiada");
          this.submitted = false;
        },
        error: err => {
          this.spinner.hide();
          err.error.split(',').forEach((error: string) => {
            switch (error) {
              case 'PasswordMismatch':
                this.userService.changePasswordForm.get('OldPassword')?.setErrors({ passwordMismatch: true });
                break;
              case 'PasswordTooShort':
                this.userService.changePasswordForm.get('NewPasswords.Password')?.setErrors({ minlength: true });
                break;
              default:
                this.toastr.error('Error cambiando la contraseña');
                console.log(err);
                break;
            }
          });
        }
      });
  }
}
