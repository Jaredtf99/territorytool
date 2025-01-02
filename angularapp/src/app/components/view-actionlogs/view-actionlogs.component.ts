import { Component, OnInit, Input, Inject } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { NgxSpinnerService } from "ngx-spinner";
import { TabulatorFull as Tabulator } from 'tabulator-tables';
import { TimeagoPipe } from 'ngx-timeago';


@Component({
  selector: 'app-view-actionlogs',
  templateUrl: './view-actionlogs.component.html',
  styleUrls: ['./view-actionlogs.component.css'],
  providers: [TimeagoPipe]
})
export class ViewActionlogsComponent implements OnInit {

  actionlogs: any[] = [];


  constructor(public http: HttpClient, @Inject('BASE_URL') public baseUrl: string, private spinner: NgxSpinnerService, private timeagoPipe: TimeagoPipe) {
    this.spinner.show();
    http.get<any[]>(`${baseUrl}/actionlogs`).subscribe({
      next: res => {
        this.spinner.hide();
        this.actionlogs = res;
        this.buildTabulatorTable();
      },
      error: error => {
        this.spinner.hide();
        console.error(error);
      }
    });

  }

  buildTabulatorTable() {
    new Tabulator("#actionlogs_table", {
      maxHeight: "100%",
      data: this.actionlogs,
      layout: "fitColumns",
      initialSort: [
        { column: "DateUtc", dir: "desc" }
      ],
      columns: [
        { title: "Type", field: "ActionType", headerFilter: "input" },
        {
          title: "Date", 
          field: "DateUtc", 
          formatter: (cell) => {
            return this.timeagoPipe.transform(cell.getValue());
          }
        },
        { title: "UserName", field: "UserName", headerFilter: "input" },
        { title: "Message", field: "Message", headerFilter: "input" },
        { title: "Successful", field: "Successful", formatter: "tickCross" },
      ],
    });
  }

  ngOnInit() {

  }


}
