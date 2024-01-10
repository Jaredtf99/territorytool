import { Component, EventEmitter, Input, Output } from '@angular/core';
import { ToastrService } from 'ngx-toastr';
import { NgxSpinnerService } from "ngx-spinner";
import { TerritoryService } from '../../shared/territory.service';

declare var $: any;

@Component({
  selector: 'delete-territory-modal',
  templateUrl: './delete-territory-modal.component.html'
})
export class DeleteTerritoryModalComponent {

  @Input() territoryId!: number;
  @Output() territoryDeleted: EventEmitter<void> = new EventEmitter<void>();

  constructor(private toastr: ToastrService, private spinner: NgxSpinnerService, public territoryService: TerritoryService) {
  }

  openModal(): void {
    $('#deleteTerritory').modal('show');
  }

  deleteTerritory() {
    this.spinner.show();
    $('#deleteTerritory').modal('hide');

    this.territoryService.deleteTerritory(this.territoryId).subscribe(
      {
        next: res => {
          this.territoryDeleted.emit();
          this.spinner.hide();
          this.toastr.success('Territorio eliminado');
        },
        error: err => {
          this.spinner.hide();
          this.toastr.error("Error desconocido");
        }
      });

  }


}
