import { Component, OnInit } from '@angular/core';
import { TerritoryTransactionService } from '../../services/territory-transaction.service';
import { TerritoryTransaction } from '../../classes/territory-transaction.model';

@Component({
  selector: 'app-recent-transactions',
  templateUrl: './recent-transactions.component.html'
})
export class RecentTransactionsComponent implements OnInit {
  transactions: TerritoryTransaction[] = [];

  constructor(private transactionService: TerritoryTransactionService) { }

  ngOnInit(): void {
    this.loadRecentTransactions();
  }

  loadRecentTransactions() {
    this.transactionService.getRecentTransactions()
      .subscribe(transactions => this.transactions = transactions);
  }
}
