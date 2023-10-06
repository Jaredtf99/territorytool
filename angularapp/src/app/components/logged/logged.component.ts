import { Component, OnInit } from '@angular/core';
import { Router } from '@angular/router';
import { AppService } from '../../shared/app.service';

@Component({
  selector: 'app-logged',
  templateUrl: './logged.component.html',
  styleUrls: ['./logged.component.css']
})
export class LoggedComponent implements OnInit {

  constructor(private router: Router, private appService: AppService) { }

  ngOnInit() {

      if (this.router.url === '/') 
        this.router.navigateByUrl('/home');

  }

  getClasses() {
    const classes = {
      'pinned-sidebar': this.appService.getSidebarStat().isSidebarPinned,
      'toggeled-sidebar': this.appService.getSidebarStat().isSidebarToggeled
    }
    return classes;
  }
  toggleSidebar() {
    this.appService.toggleSidebar();
  }


}
