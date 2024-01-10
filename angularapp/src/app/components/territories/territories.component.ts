import { Component, Inject, ViewChild } from '@angular/core';
import { UserService } from '../../shared/user.service';
import { ToastrService } from 'ngx-toastr';
import { Territory } from '../../classes/Territory';
import { NgxSpinnerService } from "ngx-spinner";
import { TerritoryService } from '../../shared/territory.service';
import { EditTerritoryModalComponent } from '../edit-territory-modal/edit-territory-modal.component';
import { DeleteTerritoryModalComponent } from '../delete-territory-modal/delete-territory-modal.component';

declare var $: any;

@Component({
  selector: 'app-territories',
  templateUrl: './territories.component.html'
})
export class TerritoriesComponent {

  @ViewChild(EditTerritoryModalComponent) editTerritoryModalComponent!: EditTerritoryModalComponent;
  @ViewChild(DeleteTerritoryModalComponent) deleteTerritoryModalComponent!: DeleteTerritoryModalComponent;

  public territories!: Territory[];
  public territoriesFiltered!: Territory[];
  public territoryToEdit: Territory = new Territory();
  public idTerritoryToDelete = 0;

  orderBy = 1;

  filterName = undefined;
  inUse = false;
  free = false;
  sortAscending = true;

  constructor(public userService: UserService, private toastr: ToastrService, private spinner: NgxSpinnerService, public territoryService: TerritoryService) {
    this.getTerritories();
  }

  getTerritories()
  {
    let apiFilterInUse: boolean | undefined;

    if (this.inUse) apiFilterInUse = true;
    if (this.free) apiFilterInUse = false;

    this.spinner.show();
    this.territoryService.getAllTerritories(this.filterName, apiFilterInUse, this.orderBy, this.sortAscending).subscribe(
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

  onChangeFree() {
    if (this.free) this.inUse = false;
    this.getTerritories();
  }

  onChangeInUse() {
    if (this.inUse) this.free = false;
    this.getTerritories();
  }

  openEditModal(territory: Territory) {
    this.territoryToEdit = { ...territory };
    this.editTerritoryModalComponent.openModal();
  }

  territoryUpdatedCallback() {
    this.getTerritories();
  }

  assignIdToDelete(idToDelete: number) {
    this.idTerritoryToDelete = idToDelete;
    this.deleteTerritoryModalComponent.openModal();

  }

  territoryDeleteCallback() {
    this.getTerritories();
  }


}
