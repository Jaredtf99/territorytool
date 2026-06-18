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

  // For storing the person being edited
  editingPerson: any = null;
  // For the edit form model
  editPersonName: string = '';
  editPersonEnabled: boolean = false;
  canEdit = false; // To control visibility of edit features

  constructor(public userService: UserService, private toastr: ToastrService, private personService: PersonService, private spinner: NgxSpinnerService) {

    this.canDelete = userService.isAdmin() || userService.isSuperAdmin();
    this.canEdit = userService.isAdmin() || userService.isSuperAdmin(); // Add this line
    this.getPersons();
  }

  public editIcon = (): string => {
    return "<i class='fa fa-pencil'></i>";
  };

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
  public deleteIcon = (): string => { // Changed to public arrow function for consistency
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
          visible: this.canDelete, // Use this.canDelete
          cellClick: (e, cell) => this.openDeleteUserModal(cell.getRow().getData().name)
        },
        // Edit column (new)
        {
          title: "", formatter: this.editIcon, width: 40, hozAlign: "center", headerSort: false,
          visible: this.canEdit, // Only visible for admin/superadmin
          cellClick: (e, cell) => this.openEditPersonModal(cell.getRow().getData())
        },
        { title: "Nombre", field: "name", headerFilter: "input" },
        {
          title: "Habilitado",
          field: "enabled",
          hozAlign: "center",
          formatter: "tickCross",
          formatterParams: { allowEmpty: false },
          width: 120
        },
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

        let territoriesInUse = row.getData().territoriesInUse;

        if (territoriesInUse && territoriesInUse.length > 0) {
          row.getElement().appendChild(holderEl);

          const processedData = territoriesInUse.map((r: any) => ({
            ...r,
            givenDate: preprocessDate(r.givenDate)
          }));

          new Tabulator(tableEl, {
            layout: "fitColumns",
            data: processedData,
            columns: [
              {
                title: "Fecha",
                field: "givenDate",
                formatter: "datetime",
                sorter: "date",
                formatterParams: {
                  inputFormat: "dd/MM/yyyy',' HH:mm:ss",
                  outputFormat: "dd/MM/yyyy HH:mm:ss",
                },
              },
              { title: "Territorio", field: "territoryName" },
              { title: "Código", field: "territoryCode" },
            ]
          });
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

  openEditPersonModal(personData: any) {
    this.editingPerson = personData;
    this.editPersonName = personData.name;
    this.editPersonEnabled = personData.enabled;
    $('#editPersonModal').modal('show');
  }

  submitEditPerson() {
    if (!this.editingPerson) {
      this.toastr.error('No se ha seleccionado ningún hermano para editar.');
      return;
    }

    this.spinner.show();
    this.personService.updatePerson(this.editingPerson.id, this.editPersonName, this.editPersonEnabled)
      .subscribe({
        next: resp => {
          this.spinner.hide();
          $('#editPersonModal').modal('hide');
          this.toastr.success('Hermano actualizado correctamente.');
          this.getPersons(); // Refresh the list
        },
        error: err => {
          this.spinner.hide();
          this.toastr.error(err.error?.message || 'Error al actualizar el hermano.');
          console.error(err);
        }
      });
  }
}

function convertUTCToLocal(utcDate: string): string {
  const date = new Date(utcDate); // Parsear la fecha
  return date.toLocaleString("en-GB"); // Convertir a la zona horaria local del navegador
}
function preprocessDate(dateString : string) : string {
  // Reemplaza los milisegundos largos (más de tres dígitos) con solo los primeros tres
  let date = dateString.replace(/\.(\d{3})\d*Z$/, '.$1Z');
  return convertUTCToLocal(date);
}
