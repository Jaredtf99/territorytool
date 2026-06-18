import { Component, AfterViewInit } from '@angular/core';
import { TabulatorFull as Tabulator } from 'tabulator-tables';
import { TimeagoPipe } from 'ngx-timeago';
import { SupabaseService } from '../../shared/supabase.service';


@Component({
  selector: 'app-view-actionlogs',
  templateUrl: './view-actionlogs.component.html',
  styleUrls: ['./view-actionlogs.component.css'],
  providers: [TimeagoPipe]
})
export class ViewActionlogsComponent implements AfterViewInit {

  constructor(private timeagoPipe: TimeagoPipe, private supabase: SupabaseService) {
  }

  buildTabulatorTable() {
    let table = new Tabulator("#actionlogs_table", {
      maxHeight: "100%",
      layout: "fitColumns",
      // Tabulator requires a non-empty ajaxURL to trigger remote loading,
      // even though ajaxRequestFunc below ignores it (we call Supabase RPC instead).
      ajaxURL: "supabase://get_action_logs",
      pagination: true,
      paginationMode: "remote",
      sortMode: "remote",
      initialSort: [
        { column: "DateUtc", dir: "desc" }, 
      ],
      paginationSize: 20,
      paginationSizeSelector: [10, 20, 50, 100],
      ajaxRequestFunc: async (url, config, params) => {
        const sort = params.sort?.[0] ?? { field: 'DateUtc', dir: 'desc' };
        const { data, error } = await this.supabase.client.rpc('get_action_logs', {
          page_number: params.page,
          page_size: params.size,
          sort_field: sort.field,
          sort_order: sort.dir
        });
        if (error) throw error;
        return {
          data: data.data.map((row: any) => ({
            ActionType: row.actionType,
            DateUtc: row.dateUtc,
            UserName: row.userName,
            Message: row.message,
            Successful: row.successful
          })),
          last_page: Math.ceil(data.totalCount / data.pageSize),
          totalCount: data.totalCount
        };
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

  ngAfterViewInit() {
    this.buildTabulatorTable();
  }


}
