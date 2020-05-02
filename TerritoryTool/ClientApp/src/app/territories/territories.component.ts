import { Component, Inject } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { UserService } from '../shared/user.service';
import { ToastrService } from 'ngx-toastr';
import { Globals } from '../globals';

declare var $: any;

@Component({
  selector: 'app-territories',
  templateUrl: './territories.component.html'
})
export class TerritoriesComponent {
  public territories: Territory[];
  public territoriesFiltered: Territory[];
  public territoryToEdit: Territory = new Territory();
  public idTerritoryToDelete: number = 0;

  filterName = '';


  constructor(public http: HttpClient, @Inject('BASE_URL') public baseUrl: string, public userService: UserService, private toastr: ToastrService, private globals: Globals) {
    globals.loading = true;
    http.get<Territory[]>(baseUrl + 'api/SampleData/AllTerritories').subscribe(result => {
      this.territories = result;
      this.territoriesFiltered = result;
      globals.loading = false;
    }, error => {
        globals.loading = false;
        console.error(error);
    })
  }

  filter()
  {
    this.territoriesFiltered = this.territories.filter(territory => territory.name.toLowerCase().includes(this.filterName.toLowerCase()));
  }

  openEditModal(idToEdit)
  {
    Object.assign(this.territoryToEdit, this.territoriesFiltered.filter(territory => territory.id === idToEdit)[0]);
  }

  editTerritory() {
    this.globals.loading = true;

    let formData = new FormData();
    formData.append('code', this.territoryToEdit.code);
    formData.append('name', this.territoryToEdit.name);
    formData.append('mapUrl', this.territoryToEdit.mapUrl);
    formData.append('id', this.territoryToEdit.id.toString());
    
    this.http.post(this.baseUrl + 'api/SampleData/editTerritory', formData).subscribe(() => {
      this.globals.loading = false;
      this.toastr.success('Territorio editado');
      Object.assign(this.territories.filter(territory => territory.id === this.territoryToEdit.id)[0], this.territoryToEdit);
      this.filter();

      $('#editTerritory').modal('hide');
    }, error => {
        this.globals.loading = false;
        if (error.error === "CODE_EXIST")
          this.toastr.error("El código ya existe");
        else if (error.error === "NAME_EXIST")
          this.toastr.error("El nombre ya existe");
        else if (error.error === "MAPURL_EXIST")
          this.toastr.error("La URL del mapa ya existe");
        else {
          this.toastr.error("Error desconocido");
          console.error(error.error);
        }
    });
  }

  assignIdToDelete(idToDelete) {
    this.idTerritoryToDelete = idToDelete;
  }

  deleteTerritory() {
    this.globals.loading = true;

    let formData = new FormData();
    formData.append('idToDelete', this.idTerritoryToDelete.toString());
    $('#deleteTerritory').modal('hide');

    this.http.post(this.baseUrl + 'api/SampleData/deleteTerritory', formData).subscribe(() => {
      this.globals.loading = false;
      this.toastr.success('Territorio eliminado');
      this.territories.splice(this.territories.indexOf(this.territoriesFiltered.filter(territory => territory.id === this.idTerritoryToDelete)[0]), 1);
      this.filter();
    }, error => {
        this.globals.loading = false;
        this.toastr.error("Error desconocido");
        console.error(error.error);
    });

  }
}

class Territory {
  id: number;
  code: string;
  name: string;
  mapUrl: string;
}
