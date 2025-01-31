import { Component, OnInit, Input, Inject } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { NgxSpinnerService } from "ngx-spinner";
import { TabulatorFull as Tabulator } from 'tabulator-tables';
import { TimeagoPipe } from 'ngx-timeago';
import { lastValueFrom } from 'rxjs';


@Component({
  selector: 'app-view-actionlogs',
  templateUrl: './view-actionlogs.component.html',
  styleUrls: ['./view-actionlogs.component.css'],
  providers: [TimeagoPipe]
})
export class ViewActionlogsComponent implements OnInit {

  constructor(public http: HttpClient, @Inject('BASE_URL') public baseUrl: string, private spinner: NgxSpinnerService, private timeagoPipe: TimeagoPipe) {
  }

  buildTabulatorTable() {
    let table = new Tabulator("#actionlogs_table", {
      maxHeight: "100%",
      layout: "fitColumns",
      pagination: true,
      paginationMode: "remote",
      sortMode: "remote",
      initialSort: [
        { column: "DateUtc", dir: "desc" }, 
      ],
      paginationSize: 20,
      paginationSizeSelector: [10, 20, 50, 100],
      ajaxURL: `${this.baseUrl}/actionlogs`,
      ajaxRequestFunc: (url, config, params) => {
        return lastValueFrom(
          this.http.get(url, {
            params: {
              pageNumber: params.page,
              pageSize: params.size,
              sortField: params.sort[0].field,
              sortOrder: params.sort[0].dir
            }
          })
        );
      },
      columns: [
        { title: "Type", field: "ActionType" },
        { 
          title: "Date", 
          field: "DateUtc",
          formatter: (cell) => {
            return this.timeagoPipe.transform(cell.getValue());
          }
        },
        { title: "UserName", field: "UserName"},
        { title: "Message", field: "Message"},
        { title: "Successful", field: "Successful", formatter: "tickCross" },
      ],
    });
  }

  ngOnInit() {
    this.buildTabulatorTable();
  }


}
