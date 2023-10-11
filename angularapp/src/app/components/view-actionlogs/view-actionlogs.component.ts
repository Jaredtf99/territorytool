import { Component, OnInit, Input, Inject } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { NgxSpinnerService } from "ngx-spinner";

@Component({
  selector: 'app-view-actionlogs',
  templateUrl: './view-actionlogs.component.html',
  styleUrls: ['./view-actionlogs.component.css']
})
export class ViewActionlogsComponent implements OnInit {

  actionlogs: any[] = [];


  constructor(public http: HttpClient, @Inject('BASE_URL') public baseUrl: string, private spinner: NgxSpinnerService) {
    this.spinner.show();
    http.get<any[]>(baseUrl + 'api/SampleData/GetAllActionLogs').subscribe(result => {
      this.spinner.hide();
      this.actionlogs = result;
    }, error => {
      this.spinner.hide();
        console.error(error);
    });

  }

  ngOnInit() {
    
  }


}
