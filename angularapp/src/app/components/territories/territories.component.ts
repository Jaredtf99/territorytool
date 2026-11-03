import { Component, Inject, ViewChild } from '@angular/core';
import { UserService } from '../../shared/user.service';
import { ToastrService } from 'ngx-toastr';
import { Territory } from '../../classes/Territory';
import { TerritoryEditInfo } from '../../classes/TerritoryEditInfo';
import { NgxSpinnerService } from "ngx-spinner";
import { TerritoryService } from '../../shared/territory.service';
import { EditTerritoryModalComponent } from '../edit-territory-modal/edit-territory-modal.component';
import { DeleteTerritoryModalComponent } from '../delete-territory-modal/delete-territory-modal.component';
import { Router } from '@angular/router';
import { DeliveryFormat } from '../../enums/DeliveryFormat';

declare var $: any;

@Component({
  selector: 'app-territories',
  templateUrl: './territories.component.html',
  styleUrls: ["./territories.component.scss"],

})
export class TerritoriesComponent {

  @ViewChild(EditTerritoryModalComponent) editTerritoryModalComponent!: EditTerritoryModalComponent;
  @ViewChild(DeleteTerritoryModalComponent) deleteTerritoryModalComponent!: DeleteTerritoryModalComponent;

  public territories!: Territory[];
  public territoriesFiltered!: Territory[];
  public territoryToEdit: TerritoryEditInfo = new TerritoryEditInfo();
  public idTerritoryToDelete = 0;
  isLoading: boolean = true;

  orderBy = 1;

  filterName = undefined;
  inUse = false;
  free = false;
  physical = false;
  virtual = false;
  sortAscending = true;

  constructor(public userService: UserService, private toastr: ToastrService, private spinner: NgxSpinnerService, public territoryService: TerritoryService, private router: Router) {
    this.getTerritories();
  }

  detail(territoryId : number | undefined)
  {
    this.router.navigate(['/territory', territoryId]);
  }

  getTerritories()
  {
    let apiFilterInUse: boolean | undefined;

    if (this.inUse) apiFilterInUse = true;
    if (this.free) apiFilterInUse = false;

    this.isLoading = true;
    this.territoryService.getAllTerritories(this.filterName, apiFilterInUse, this.orderBy, this.sortAscending, undefined, undefined).subscribe(
      {
        next: res => {
          this.territories = res;
          this.applyDeliveryFormatFilter();
          this.isLoading = false;
        },
        error: err => {
          this.isLoading = false;
          console.error(err);
        }
      });
  }

  onChangeFree() {
    if (this.free) {
      this.inUse = false;
      this.physical = false;
      this.virtual = false;
    }
    this.getTerritories();
  }

  onChangeDeliveryFormat(format: DeliveryFormat) {
    if (format === 'physical' && this.physical) this.virtual = false;
    if (format === 'virtual' && this.virtual) this.physical = false;

    // El formato sólo existe en territorios entregados: si venimos de "Libres" hay que recargar.
    if (this.free) {
      this.free = false;
      this.getTerritories();
      return;
    }
    this.applyDeliveryFormatFilter();
  }

  private applyDeliveryFormatFilter() {
    const format: DeliveryFormat | undefined = this.physical ? 'physical' : this.virtual ? 'virtual' : undefined;
    this.territoriesFiltered = format
      ? this.territories.filter(t => t.personName && t.deliveryFormat === format)
      : this.territories;
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
