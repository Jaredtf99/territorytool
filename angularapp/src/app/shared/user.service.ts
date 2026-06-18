import { Injectable } from '@angular/core';
import { FormBuilder, Validators, FormGroup } from '@angular/forms';
import { RoleType } from '../enums/RoleType';
import { User } from '../classes/User';
import { from, Observable } from 'rxjs';
import { map, switchMap } from 'rxjs/operators';
import { SupabaseService } from './supabase.service';

@Injectable()
export class UserService {

  constructor(private fb: FormBuilder, private supabase: SupabaseService) { }

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
      action: 'create',
      username: this.formModel.value.UserName,
      password: this.formModel.value.Passwords.Password,
      role: 'USER'
    };
    return from(this.supabase.invoke('admin-users', body));
  }

  login(formData: any) {
    const body = {
      username: formData.userName ?? formData.UserName ?? formData.username,
      password: formData.password ?? formData.Password
    };

    return from(this.supabase.invoke<any>('login-with-username', body)).pipe(
      switchMap(result => from(this.supabase.client.auth.setSession({
        access_token: result.session.access_token,
        refresh_token: result.session.refresh_token
      })).pipe(map(() => {
        localStorage.setItem('token', result.session.access_token);
        if (result.profile) {
          localStorage.setItem('profile', JSON.stringify(result.profile));
        }
        if (result.congregations) {
          localStorage.setItem('congregations', JSON.stringify(result.congregations));
        }
        return { token: result.session.access_token, session: result.session, congregations: result.congregations };
      })))
    );
  }

  async syncStoredToken(): Promise<string | null> {
    const token = await this.supabase.getAccessToken();
    if (token) {
      localStorage.setItem('token', token);
    } else {
      localStorage.removeItem('token');
    }
    return token;
  }

  logout(): Observable<any> {
    localStorage.removeItem('token');
    localStorage.removeItem('profile');
    localStorage.removeItem('congregations');
    return from(this.supabase.client.auth.signOut());
  }

  changePassword() {
    let body = {
      password: this.changePasswordForm.value.NewPasswords.Password ?? undefined,
      current_password: this.changePasswordForm.value.OldPassword ?? undefined
    };
    return from(this.supabase.client.auth.updateUser(body)).pipe(
      switchMap(result => {
        if (result.error) throw result.error;
        return from(this.supabase.client
          .from('profiles')
          .update({ must_change_password: false })
          .eq('id', result.data.user.id));
      })
    );
  }


  roleMatch(allowedRoles: Array<string>): boolean {
    const userRole = this.getRoleName();
    return allowedRoles.includes(userRole);
  }

  isSuperAdmin(): boolean {
    const payload = this.getTokenPayload();
    if (payload?.is_superadmin === true) return true;
    return (RoleType.SUPERADMIN === this.getRole());
  }

  // The active congregation id carried in the current JWT.
  getCongregationId(): string | null {
    return this.getTokenPayload()?.congregation_id ?? this.getStoredProfile()?.active_congregation_id ?? null;
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
    const userRole = this.getRoleName();
    return RoleType[userRole as keyof typeof RoleType];
  }

  getRoleString(role: RoleType): string {
    return RoleType[role];
  }

  getUserName(): string {
    const payload = this.getTokenPayload();
    return payload?.UserName ?? this.getStoredProfile()?.username ?? '';

  }

  getAllUsers(): Observable<User[]> {
    return from(this.supabase.invoke<any[]>('admin-users', { action: 'list' })).pipe(
      map(users => users.map(user => ({
        UserID: user.id,
        UserName: user.username,
        Role: user.role
      })))
    );
  }

  editUser(userId: string, userName: string, role: string): Observable<any> {
    let body = {
      userName,
      role: RoleType[role as keyof typeof RoleType]
    };

    return from(this.supabase.invoke('admin-users', {
      action: 'update',
      userId,
      username: userName,
      role
    }));
  }

  deleteUser(id: string): Observable<any> {
    return from(this.supabase.invoke('admin-users', { action: 'delete', userId: id }))
  }

  public changeUserPassword(userId: string, newPassword: string): Observable<any> {
    return from(this.supabase.invoke('admin-users', {
      action: 'change-password',
      userId,
      newPassword
    }));
  }

  private getTokenPayload(): any {
    const token = localStorage.getItem('token');
    if (!token) return null;
    try {
      return JSON.parse(window.atob(token.split('.')[1]));
    } catch {
      return null;
    }
  }

  private getRoleName(): string {
    const payload = this.getTokenPayload();
    return payload?.app_role ?? this.getStoredProfile()?.role ?? '';
  }

  private getStoredProfile(): any {
    const raw = localStorage.getItem('profile');
    if (!raw) return null;
    try {
      return JSON.parse(raw);
    } catch {
      return null;
    }
  }

}
