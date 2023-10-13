import { Component, Inject } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { UserService } from '../../shared/user.service';
import { ToastrService } from 'ngx-toastr';
import { Territory } from '../../classes/Territory';
import { NgxSpinnerService } from "ngx-spinner";
import { TerritoryService } from '../../shared/territory.service';

declare var $: any;

@Component({
  selector: 'app-territories',
  templateUrl: './territories.component.html'
})
export class TerritoriesComponent {
  public territories!: Territory[];
  public territoriesFiltered!: Territory[];
  public territoryToEdit: Territory = new Territory();
  public idTerritoryToDelete = 0;

  filterName = '';


  constructor(public http: HttpClient, @Inject('BASE_URL') public baseUrl: string, public userService: UserService, private toastr: ToastrService, private spinner: NgxSpinnerService, public territoryService: TerritoryService) {
    this.spinner.show();
    territoryService.getAllTerritories().subscribe(
      {
        next: res => {
          this.territories = res;
          this.territoriesFiltered = res;
          this.spinner.hide();
        },
        error: err => {
          this.spinner.hide();
          console.error(err);
        }
      });
  }

  filter()
  {
    this.territoriesFiltered = this.territories.filter(territory => territory.name!.toLowerCase().includes(this.filterName.toLowerCase()));
  }

  openEditModal(idToEdit: number)
  {
    Object.assign(this.territoryToEdit, this.territoriesFiltered.filter(territory => territory.id === idToEdit)[0]);
  }

  editTerritory() {
    this.spinner.show();

    let tEdit = this.territoryToEdit;
    this.territoryService.editTerritory(tEdit.id!, tEdit.mapUrl!, tEdit.name!, tEdit.code!).subscribe(
      {
        next: res => {
          this.spinner.hide();
          this.toastr.success('Territorio editado');
          Object.assign(this.territories.filter(territory => territory.id === this.territoryToEdit.id)[0], this.territoryToEdit);
          this.filter();
          $('#editTerritory').modal('hide');
        },
        error: err => {
          this.spinner.hide();
          if (err.error === "CODE_EXIST")
            this.toastr.error("El código ya existe");
          else if (err.error === "NAME_EXIST")
            this.toastr.error("El nombre ya existe");
          else if (err.error === "MAPURL_EXIST")
            this.toastr.error("La URL del mapa ya existe");
          else {
            this.toastr.error("Error desconocido");
          }
        }
      }
    );
  }

  assignIdToDelete(idToDelete: number) {
    this.idTerritoryToDelete = idToDelete;
  }

  deleteTerritory() {
    this.spinner.show();

    $('#deleteTerritory').modal('hide');

    this.territoryService.deleteTerritory(this.idTerritoryToDelete).subscribe(
      {
        next: res => {
          this.spinner.hide();
          this.toastr.success('Territorio eliminado');
          this.territories.splice(this.territories.indexOf(this.territoriesFiltered.filter(territory => territory.id === this.idTerritoryToDelete)[0]), 1);
          this.filter();
        },
        error: err => {
          this.spinner.hide();
          this.toastr.error("Error desconocido");
        }
      });

  }
}
