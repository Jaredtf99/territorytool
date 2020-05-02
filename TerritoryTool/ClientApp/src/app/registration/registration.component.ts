import { Component, OnInit } from '@angular/core';
import { UserService } from '../shared/user.service';
import { ToastrService } from 'ngx-toastr';
import { Globals } from '../globals';

@Component({
  selector: 'app-registration',
  templateUrl: './registration.component.html',
  styleUrls: ['./registration.component.css']
})
export class RegistrationComponent implements OnInit {

  constructor(public userService: UserService, private toastr: ToastrService, private globals: Globals) { }

  ngOnInit() {
  }

  register() {
    this.globals.loading = true;

    this.userService.register().subscribe(
      (res: any) => {
        this.globals.loading = false;
        if (res.succeeded) {
          this.userService.formModel.reset();
          this.toastr.success("Registro con éxito");
        } else if (res.errors != null) {
          res.errors.forEach(element => {
            switch (element.code) {
              case 'DuplicateUserName':
                this.toastr.error("El usuario ya existe");
                break;
              default:
                this.toastr.error(element.descript, 'Registration failed');
                break;
            }
          });
        }
      },
      err => {
        this.globals.loading = false;
        console.log(err);
      }
    )
  }

}
