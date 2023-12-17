import { Component, OnInit, Input, Inject } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { NgxSpinnerService } from "ngx-spinner";
import { TabulatorFull as Tabulator } from 'tabulator-tables';


@Component({
  selector: 'app-view-actionlogs',
  templateUrl: './view-actionlogs.component.html',
  styleUrls: ['./view-actionlogs.component.css']
})
export class ViewActionlogsComponent implements OnInit {

  actionlogs: any[] = [];


  constructor(public http: HttpClient, @Inject('BASE_URL') public baseUrl: string, private spinner: NgxSpinnerService) {
    this.spinner.show();
    http.get<any[]>(`${baseUrl}/actionlogs`).subscribe({
      next: res => {
        this.spinner.hide();
        this.actionlogs = res;

        var table = new Tabulator("#actionlogs_table", {
          height: 700,
          data: res,
          layout: "fitColumns",
          columns: [
            { title: "Type", field: "ActionType" },
            {
              title: "Date", field: "DateUtc", formatter: "datetimediff", formatterParams: {
                inputFormat: "yyyy-MM-dd'T'TT",
                humanize: true,
              }
            },
            { title: "UserName", field: "UserName" },
            { title: "Message", field: "Message" },
            { title: "Successful", field: "Successful", formatter: "tickCross" },
          ],
        });
      },
      error: error => {
        this.spinner.hide();
        console.error(error);
      }
    });

  }

  ngOnInit() {

  }


}
