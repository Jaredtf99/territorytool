import { Injectable, Inject } from '@angular/core';
import { FormBuilder, Validators, FormGroup } from '@angular/forms';
import { HttpClient } from '@angular/common/http'

@Injectable()
export class UserService {

  constructor(private fb: FormBuilder, private http: HttpClient, @Inject('BASE_URL') private baseUrl: string) { }

  formModel = this.fb.group(
    {
      UserName: ['', Validators.required],
      Passwords: this.fb.group(
        {
          Password: ['', [Validators.required, Validators.minLength(4)]],
          ConfirmPassword: ['', Validators.required]
        }, { validator : this.comparePasswords})
    });

  comparePasswords(fb:FormGroup) {
    let confirmPswrdCtrl = fb.get('ConfirmPassword');

    if (confirmPswrdCtrl.errors == null || 'passwordMismatch' in confirmPswrdCtrl.errors) {
      if (fb.get('Password').value != confirmPswrdCtrl.value)
        confirmPswrdCtrl.setErrors({ passwordMismatch: true });
      else
        confirmPswrdCtrl.setErrors(null);
    }
  }

  register() {
    let body = {
      UserName: this.formModel.value.UserName,
      Password: this.formModel.value.Passwords.Password
    };
    return this.http.post(this.baseUrl + 'api/user/register', body);
  }

  login(formData) {
    return this.http.post(this.baseUrl + 'api/user/login', formData);
  }

  roleMatch(allowedRoles: Array<string>): boolean {
    const payload = JSON.parse(window.atob(localStorage.getItem('token').split('.')[1]));
    const userRole = payload.role;
    return allowedRoles.includes(userRole);
  }

  isSuperAdmin(): boolean {
    const payload = JSON.parse(window.atob(localStorage.getItem('token').split('.')[1]));
    const userRole = payload.role;
    return ("SUPERADMIN" === userRole);
  }

  isAdmin(): boolean {
    const payload = JSON.parse(window.atob(localStorage.getItem('token').split('.')[1]));
    const userRole = payload.role;
    return ("ADMIN" === userRole);
  }

  isUser(): boolean {
    const payload = JSON.parse(window.atob(localStorage.getItem('token').split('.')[1]));
    const userRole = payload.role;
    return ("USER" === userRole);
  }

}
