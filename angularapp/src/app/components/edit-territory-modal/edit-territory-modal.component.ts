import { Component, ElementRef, EventEmitter, Input, Output } from '@angular/core';
import { ToastrService } from 'ngx-toastr';
import { Territory } from '../../classes/Territory';
import { NgxSpinnerService } from "ngx-spinner";
import { TerritoryService } from '../../shared/territory.service';

declare var $: any;

@Component({
  selector: 'edit-territory-modal',
  templateUrl: './edit-territory-modal.component.html'
})
export class EditTerritoryModalComponent {

  @Input() territoryInfo!: Territory;
  @Output() territoryUpdated: EventEmitter<void> = new EventEmitter<void>();

  constructor(private toastr: ToastrService, private spinner: NgxSpinnerService, public territoryService: TerritoryService, private el: ElementRef) {
  }

  openModal(): void {
    $('#editTerritory').modal('show');
  }

  editTerritory() {
    this.spinner.show();

    $('#editTerritory').modal('hide');

    let tEdit = this.territoryInfo;
    this.territoryService.editTerritory(tEdit.id!, tEdit.mapUrl!, tEdit.name!, tEdit.code!).subscribe(
      {
        next: res => {
          this.territoryUpdated.emit();
          this.spinner.hide();
          this.toastr.success('Territorio editado');
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

}
