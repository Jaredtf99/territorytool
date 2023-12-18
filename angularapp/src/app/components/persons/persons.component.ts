import { Component, OnInit, Inject } from '@angular/core';
import { UserService } from '../../shared/user.service';
import { ToastrService } from 'ngx-toastr';
import { PersonService } from '../../shared/person.service';
import { NgxSpinnerService } from "ngx-spinner";
import { CellComponent, TabulatorFull as Tabulator } from 'tabulator-tables';

declare var $: any;

@Component({
  selector: 'app-persons',
  templateUrl: './persons.component.html',
  styleUrls: ['./persons.component.css']
})
export class PersonsComponent {

  persons: any[] = [];
  canDelete = false;
  public personNameToDelete = '';

  constructor(public userService: UserService, private toastr: ToastrService, private personService: PersonService, private spinner: NgxSpinnerService) {

    this.canDelete = userService.isAdmin() || userService.isSuperAdmin();
    this.getPersons();
  }

  getPersons() {

    this.spinner.show();

    this.personService.getAllPersons()
      .subscribe({
        next: resp => {
          this.spinner.hide();
          this.persons = resp;
          this.buildTabulatorTable();
        },
        error: err => {
          this.spinner.hide();
          console.error(err);
        }
      });

  }
  deleteIcon = function () {
    return "<i class='fa fa-trash-can'></i>";
  };

  buildTabulatorTable() {
    new Tabulator("#person_table", {
      data: this.persons,
      layout: "fitColumns",
      maxHeight: "100%",
      columns: [
        {
          title: "", formatter: this.deleteIcon, width: 40, hozAlign: "center", headerSort: false,
          cellClick: (e, cell) => this.openDeleteUserModal(cell.getRow().getData().Name)
        },
        { title: "Name", field: "Name", headerFilter: "input" },
      ],
      rowFormatter: function (row) {
        //create and style holder elements
        var holderEl = document.createElement("div");
        var tableEl = document.createElement("div");

        holderEl.style.boxSizing = "border-box";
        holderEl.style.padding = "10px 30px 10px 10px";
        holderEl.style.borderTop = "1px solid #333";
        holderEl.style.borderBottom = "1px solid #333";


        tableEl.style.border = "1px solid #333";

        holderEl.appendChild(tableEl);

        let territoriesInUse = row.getData().TerritoriesInUse;

        if (territoriesInUse.length > 0) {
          row.getElement().appendChild(holderEl);

          var subTable = new Tabulator(tableEl, {
            layout: "fitColumns",
            data: row.getData().TerritoriesInUse,
            columns: [
              { title: "Fecha", field: "GivenDate", formatter: "datetime", sorter: "date", formatterParams: { inputFormat: "yyyy-MM-dd'T'TT" } },
              { title: "Territorio", field: "TerritoryName" },
              { title: "Código", field: "TerritoryCode" },
            ]
          })
        }
      },
    });


  }

  openDeleteUserModal(nameToDelete: string) {
    $('#deletePerson').modal('show');
    this.personNameToDelete = nameToDelete;
  }

  deletePerson() {
    this.spinner.show();

    $('#deletePerson').modal('hide');

    this.personService.deletePerson(this.personNameToDelete).subscribe(
      {
        next: resp => {
          this.getPersons();
          this.toastr.success('Hermano eliminado');
        },
        error: err => {
          this.spinner.hide();
          this.toastr.error("Error desconocido");
        }
      });

  }


}
