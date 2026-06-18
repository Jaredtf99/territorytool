import { AppService } from '../../shared/app.service';
import { Component, OnInit } from '@angular/core';
import { UserService } from '../../shared/user.service';
import { Congregation, CongregationService } from '../../shared/congregation.service';

@Component({
  selector: 'app-navbar',
  templateUrl: './navbar.component.html',
  styleUrls: ['./navbar.component.scss']
})
export class NavbarComponent implements OnInit {

  constructor(
    private appService: AppService,
    public userService: UserService,
    public congregationService: CongregationService
  ) { }

  isCollapsed = true;
  congregations: Congregation[] = [];
  active: Congregation | null = null;
  switching = false;

  ngOnInit() {
    this.congregationService.congregations$.subscribe(list => {
      this.congregations = list;
      this.active = list.find(c => c.is_active) ?? null;
    });
  }

  switchCongregation(id: string) {
    if (this.switching || this.active?.id === id) return;
    this.switching = true;
    this.congregationService.switchCongregation(id).subscribe({
      next: () => {
        this.switching = false;
        // Reload so all screens re-fetch data for the new congregation.
        window.location.reload();
      },
      error: () => { this.switching = false; }
    });
  }

  toggleSidebarPin() {
    this.appService.toggleSidebarPin();
  }
  toggleSidebar() {
    this.appService.toggleSidebar();
  }

}
