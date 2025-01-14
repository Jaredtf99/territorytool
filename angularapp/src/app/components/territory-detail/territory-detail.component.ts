import { Component, OnInit, Inject, ViewChild, ElementRef, AfterViewInit } from '@angular/core';
import { FormGroup, FormBuilder, Validators } from '@angular/forms';
import { Toast, ToastrService } from 'ngx-toastr';
import { PersonService } from '../../shared/person.service';
import { NgxSpinnerService } from "ngx-spinner";
import { ActivatedRoute, Router } from '@angular/router';
import { TerritoryService } from '../../shared/territory.service';
import { TerritoryDetail } from '../../classes/TerritoryDetail';
import { TerritoryEditInfo } from '../../classes/TerritoryEditInfo';
import { EditTerritoryModalComponent } from '../edit-territory-modal/edit-territory-modal.component';
import { DeleteTerritoryModalComponent } from '../delete-territory-modal/delete-territory-modal.component';
import { TerritoryTransactionService } from 'src/app/services/territory-transaction.service';
import { EditTransactionModalComponent } from '../edit-transaction-modal/edit-transaction-modal.component';

declare var $: any;

@Component({
  selector: 'territory-detail',
  templateUrl: './territory-detail.component.html',
  styleUrls: ['./territory-detail.component.css']
})
export class TerritoryDetailComponent implements OnInit {

  territoryId!: number;
  territoryInfo: TerritoryDetail | undefined;
  territoryToEdit: TerritoryEditInfo = new TerritoryEditInfo();
  @ViewChild(EditTerritoryModalComponent) editTerritoryModalComponent!: EditTerritoryModalComponent;
  @ViewChild(DeleteTerritoryModalComponent) deleteTerritoryModalComponent!: DeleteTerritoryModalComponent;
  territoryStats: any;

  @ViewChild('timelineScroll') timelineScroll!: ElementRef;
  @ViewChild('editTransactionModal') editTransactionModal!: EditTransactionModalComponent;

  constructor(
    private route: ActivatedRoute, 
    public territoryService: TerritoryService, 
    private toastr: ToastrService, 
    private spinner: NgxSpinnerService, 
    private router: Router,
    private transactionService: TerritoryTransactionService
  ) {

  }

  ngOnInit(): void {
    this.route.params.subscribe(params => {
      this.territoryId = params['id'];
      this.getTerritoryInfo();
      this.getTerritoryStats();
      
      // Esperamos a que los datos se carguen antes de inicializar el scroll
      setTimeout(() => {
        if (this.timelineScroll) {
          this.initDragScroll();
        }
      }, 100);
    });
  }

  viewTransactions()
  {
    this.router.navigate(['/territory', this.territoryId, 'transactions']);
  }
  getTerritoryInfo() {
    this.territoryService.getTerritoryDetailInfo(this.territoryId).subscribe(
      {
        next: res => {
          this.territoryInfo = res
          this.territoryInfo.timelineItems!.sort((a: any, b: any) => {
            return new Date(b.date).getTime() - new Date(a.date).getTime();
          });
          this.spinner.hide();
        },
        error: err => {
          this.spinner.hide();
          console.error(err);
        }
      });

  }

  getTerritoryStats() {
    this.territoryService.getTerritoryStatistics(this.territoryId).subscribe({
      next: res => {
        this.territoryStats = res;
      },
      error: err => {
        console.error(err);
      }
    });
  }

  openPickTerritoryConfirm() {
    $('#pickTerritory').modal('show');
  }

  pickTerritory() {
    this.router.navigate(['/pick-territory', this.territoryInfo!.code]);
  }

  refreshTerritoryImage() {
    this.spinner.show();

    this.territoryService.refreshTerritoryImage(this.territoryId).subscribe(
      {
        next: res => {
          this.toastr.success('Imagen actualizada');
          this.getTerritoryInfo();
        },
        error: err => {
          this.toastr.error('Error actualizando la imagen');
          this.spinner.hide();
          console.error(err);
        }
      });

  }

  openEditModal() {
    this.territoryToEdit = { ...this.territoryInfo };
    this.editTerritoryModalComponent.openModal();
  }

  openDeleteModal() {
    this.deleteTerritoryModalComponent.openModal();
  }

  territoryUpdatedCallback() {
    this.getTerritoryInfo();
  }

  territoryDeleteCallback() {
    this.router.navigate(['/territories']);
  }

  private initDragScroll() {
    const slider = this.timelineScroll.nativeElement;
    let isDown = false;
    let startX: number;
    let scrollLeft: number;

    const onMouseDown = (e: MouseEvent) => {
      isDown = true;
      slider.classList.add('active');
      startX = e.pageX;
      scrollLeft = slider.scrollLeft;
    };

    const onMouseLeave = () => {
      isDown = false;
      slider.classList.remove('active');
    };

    const onMouseUp = () => {
      isDown = false;
      slider.classList.remove('active');
    };

    const onMouseMove = (e: MouseEvent) => {
      if (!isDown) return;
      e.preventDefault();
      const walk = e.pageX - startX;
      slider.scrollLeft = scrollLeft - walk;
    };

    slider.addEventListener('mousedown', onMouseDown);
    slider.addEventListener('mouseleave', onMouseLeave);
    slider.addEventListener('mouseup', onMouseUp);
    slider.addEventListener('mousemove', onMouseMove);
  }

  editTransaction(transactionId: number) {
    this.editTransactionModal.transactionId = transactionId;
    this.editTransactionModal.openModal();
  }
  
  onTransactionUpdated(): void {
    this.getTerritoryInfo();
  }

  deleteTransaction(id: number) {
    if (confirm('¿Estás seguro de que deseas eliminar esta transacción?')) {
      this.transactionService.deleteTransaction(id)
        .subscribe(() => {
          this.toastr.success('Transaccion eliminada');
          this.getTerritoryInfo();
        });
    }
  }

  giveTerritory() {
    this.router.navigate(['/change-territory', this.territoryInfo!.code]);
  }

}

