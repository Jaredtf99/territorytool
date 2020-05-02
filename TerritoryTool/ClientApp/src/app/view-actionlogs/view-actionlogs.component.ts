import { Component, OnInit, Input, Inject } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Globals } from '../globals';

@Component({
  selector: 'app-view-actionlogs',
  templateUrl: './view-actionlogs.component.html',
  styleUrls: ['./view-actionlogs.component.css']
})
export class ViewActionlogsComponent implements OnInit {

  actionlogs: any[] = [];


  constructor(public http: HttpClient, @Inject('BASE_URL') public baseUrl: string, private globals: Globals) {
    this.globals.loading = true;
    http.get<any[]>(baseUrl + 'api/SampleData/GetAllActionLogs').subscribe(result => {
      this.globals.loading = false;
      this.actionlogs = result;
    }, error => {
        this.globals.loading = false;
        console.error(error);
    });

  }

  ngOnInit() {
    
  }


}
