import { Injectable } from '@angular/core';
import { ActivatedRouteSnapshot, RouterStateSnapshot, Router, CanActivateChild } from '@angular/router';
import { UserService } from '../shared/user.service';


@Injectable()
export class AuthGuard implements CanActivateChild {

  constructor(private router: Router, private userService: UserService) { }

  canActivateChild(
    next: ActivatedRouteSnapshot,
    state: RouterStateSnapshot): boolean {
    if (localStorage.getItem('token') != null) {
      const roles = next.data['permittedRoles'] as Array<string>;

      if (roles) {
        if (this.userService.roleMatch(roles))
          return true;
        else {
          this.router.navigate(['/forbidden']);
          return false;
        }
        
      }

      return true;
    }
    else {
      this.router.navigate(['/login']);
      return false;
    }
  }
}
