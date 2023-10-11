import { Component, OnInit } from '@angular/core';
import { NgForm } from '@angular/forms';
import { UserService } from '../../shared/user.service';
import { Router } from '@angular/router';
import { ToastrService } from 'ngx-toastr';
import { NgxSpinnerService } from "ngx-spinner";

@Component({
  selector: 'app-login',
  templateUrl: './login.component.html',
  styleUrls: ['./login.component.css']
})
export class LoginComponent implements OnInit {

  formModel = {
    UserName: '',
    Password: ''
  }

  constructor(public userService: UserService, private router: Router, private toastr: ToastrService, private spinner: NgxSpinnerService) { }

  ngOnInit() {
    if (localStorage.getItem('token') != null) {
      this.router.navigateByUrl('/home');
    }

  }

  login(form: NgForm) {

    this.spinner.show();

    this.userService.login(form.value).subscribe(
      {
        next: (resp: any) => {
          localStorage.setItem('token', resp.token);
          this.router.navigateByUrl('/home');
        },
        error: err => {
          if (err.status == 400) {
            this.toastr.error('Usuario o contraseña incorrecta');
          }
          else {
            console.log(err);
          }
        },
        complete: () => {
          this.spinner.hide();
        }
      }
    );
  }

}
