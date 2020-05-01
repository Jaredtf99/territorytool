import { Component, OnInit, Input, Inject } from '@angular/core';
import { HttpClient } from '@angular/common/http';

@Component({
  selector: 'app-view-actionlogs',
  templateUrl: './view-actionlogs.component.html',
  styleUrls: ['./view-actionlogs.component.css']
})
export class ViewActionlogsComponent implements OnInit {

  actionlogs: any[] = [];


  constructor(public http: HttpClient, @Inject('BASE_URL') public baseUrl: string) {
    http.get<any[]>(baseUrl + 'api/SampleData/GetAllActionLogs').subscribe(result => {
      this.actionlogs = result;
    }, error => console.error(error));

  }

  ngOnInit() {
    
  }


}
