import { Component, OnInit, ViewChild } from '@angular/core';
import { ActivatedRoute } from '@angular/router';
import { TerritoryTransactionService } from '../../services/territory-transaction.service';
import { TerritoryTransaction } from '../../classes/territory-transaction.model';
import { EditTransactionModalComponent } from '../edit-transaction-modal/edit-transaction-modal.component';
import { ToastrService } from 'ngx-toastr';

@Component({
  selector: 'app-territory-transactions',
  templateUrl: './territory-transactions.component.html'
})
export class TerritoryTransactionsComponent implements OnInit {
  @ViewChild('editTransactionModal') editTransactionModal!: EditTransactionModalComponent;
  
  transactions: TerritoryTransaction[] = [];
  territoryId!: number;
  
  constructor(
    private route: ActivatedRoute,
    private transactionService: TerritoryTransactionService,
    private toastr: ToastrService,
  ) {}

  ngOnInit() {
    this.route.params.subscribe(params => {
      this.territoryId = params['id'];
      this.loadTransactions();
    });
  }

  loadTransactions() {
    this.transactionService.getTransactions(this.territoryId)
      .subscribe(transactions => this.transactions = transactions);
  }


  openEditTransactionModal(id: number) {
    this.editTransactionModal.transactionId = id;
    this.editTransactionModal.openModal();
  }

  onTransactionUpdated(): void {
    this.loadTransactions();
  }

  deleteTransaction(id: number) {
    if (confirm('¿Estás seguro de que deseas eliminar esta transacción?')) {
      this.transactionService.deleteTransaction(id)
        .subscribe(() => {
          this.toastr.success('Transaccion eliminada');
          this.loadTransactions();
        });
    }
  }
} 