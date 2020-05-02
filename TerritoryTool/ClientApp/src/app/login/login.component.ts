import { Component, OnInit } from '@angular/core';
import { NgForm } from '@angular/forms';
import { UserService } from '../shared/user.service';
import { Router } from '@angular/router';
import { ToastrService } from 'ngx-toastr';
import { Globals } from '../globals';

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

  constructor(public userService:UserService, private router:Router, private toastr:ToastrService, private globals: Globals) { }

  ngOnInit() {
    if (localStorage.getItem('token') != null) {
      this.router.navigateByUrl('/home');
    }
    
  }

  login(form: NgForm) {

    this.globals.loading = true;

    this.userService.login(form.value).subscribe(
      (res: any) => {
        this.globals.loading = false;
        localStorage.setItem('token', res.token);
        this.router.navigateByUrl('/home');
      },
      err => {
        this.globals.loading = false;
        if (err.status == 400) {
          this.toastr.error('Usuario o contraseña incorrecta');
        }
        else
          console.log(err);
      }
    );
  }

}
