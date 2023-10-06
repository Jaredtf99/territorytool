import { Component } from '@angular/core';
import { Router } from '@angular/router';
import { UserService } from '../../shared/user.service';
import { AppService } from '../../shared/app.service';

@Component({
  selector: 'app-newsidebar',
  templateUrl: './newsidebar.component.html',
  styleUrls: ['./newsidebar.component.scss']
})
export class NewSidebarComponent {
  isExpanded = false;

  constructor(private router: Router, public userService: UserService, private appService: AppService) { }

  collapse() {
    this.isExpanded = false;
  }

  toggleSidebar() {
    this.appService.toggleSidebar();
  }

  toggleSidebarPin() {
    this.appService.toggleSidebarPin();
  }

  logout()
  {
    localStorage.removeItem('token');
    this.router.navigate(['/login']);
  }
}
