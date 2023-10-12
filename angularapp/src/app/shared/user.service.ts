import { Injectable, Inject } from '@angular/core';
import { FormBuilder, Validators, FormGroup } from '@angular/forms';
import { HttpClient } from '@angular/common/http'
import { RoleType } from '../enums/RoleType';
import { User } from '../classes/User';
import { Observable } from 'rxjs';

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

  changePasswordForm = this.fb.group(
    {
      OldPassword: ['', [Validators.required, Validators.minLength(4)]],
      NewPasswords: this.fb.group(
        {
          Password: ['', [Validators.required, Validators.minLength(4)]],
          ConfirmPassword: ['', Validators.required]
        }, { validator: this.comparePasswords })
    });

  comparePasswords(fb:FormGroup) {
    let confirmPswrdCtrl = fb.get('ConfirmPassword')!;

    if (confirmPswrdCtrl.errors == null || 'passwordMismatch' in confirmPswrdCtrl.errors) {
      if (fb.get('Password')!.value != confirmPswrdCtrl.value)
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

  login(formData: any) {
    return this.http.post(this.baseUrl + 'api/user/login', formData);
  }

  changePassword() {
    let body = {
      OldPassword: this.changePasswordForm.value.OldPassword,
      NewPassword: this.changePasswordForm.value.NewPasswords.Password
    };
    return this.http.post(this.baseUrl + 'api/user/change-password', body);
  }


  roleMatch(allowedRoles: Array<string>): boolean {
    const payload = JSON.parse(window.atob(localStorage.getItem('token')!.split('.')[1]));
    const userRole = payload.role;
    return allowedRoles.includes(userRole);
  }

  isSuperAdmin(): boolean {
    const userRole = this.getRole();
    return (RoleType.SUPERADMIN === userRole);
  }

  isAdmin(): boolean {
    const userRole = this.getRole();
    return (RoleType.ADMIN === userRole);
  }

  isUser(): boolean {
    const userRole = this.getRole();
    return (RoleType.USER === userRole);
  }

  getRole(): RoleType {
    const payload = JSON.parse(window.atob(localStorage.getItem('token')!.split('.')[1]));
    const userRole = payload.role;
    return RoleType[userRole as keyof typeof RoleType];
  }

  getRoleString(role: RoleType): string {
    return RoleType[role];
  }

  getUserName(): string {
    const payload = JSON.parse(window.atob(localStorage.getItem('token')!.split('.')[1]));
    return payload.UserName;

  }

  getAllUsers(): Observable<User[]> {
    return this.http.get<User[]>(this.baseUrl + 'api/user/get-users').pipe()
  }

  editUser(userId: string, userName: string, role: string): Observable<any> {
    let body = {
      userId,
      userName,
      role: RoleType[role as keyof typeof RoleType]
    };

    return this.http.post(this.baseUrl + 'api/user/edit-user', body).pipe()
  }

  deleteUser(id: string): Observable<any> {
    return this.http.get(this.baseUrl + 'api/user/delete-user?idToDelete=' + id).pipe()
  }


}
