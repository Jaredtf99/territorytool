import { Component, OnInit } from '@angular/core';
import { Router } from '@angular/router';

@Component({
  selector: 'app-logged',
  templateUrl: './logged.component.html',
  styleUrls: ['./logged.component.css']
})
export class LoggedComponent implements OnInit {

  constructor(private router: Router) { }

  ngOnInit() {

      if (this.router.url === '/') 
        this.router.navigateByUrl('/home');

  }

}
