import { Component } from '@angular/core';
import { Router } from '@angular/router';
import { Globals } from './globals';
import { strings as spanishStrings } from "ngx-timeago/language-strings/es";
import { TimeagoIntl } from "ngx-timeago";

@Component({
  selector: 'app-root',
  templateUrl: './app.component.html'
})
export class AppComponent {
  title = 'app';

  constructor(private router: Router, public globals: Globals, intl: TimeagoIntl) { 
    intl.strings = spanishStrings;
    intl.changes.next();
  }

}
