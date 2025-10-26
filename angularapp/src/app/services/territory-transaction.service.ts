import { Injectable, Inject } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';
import { TerritoryTransaction } from '../classes/territory-transaction.model';

@Injectable()
export class TerritoryTransactionService {

  constructor(private http: HttpClient, @Inject('BASE_URL') private baseUrl: string) { }

  getTransactions(territoryId: number): Observable<TerritoryTransaction[]> {
    return this.http.get<TerritoryTransaction[]>(`${this.baseUrl}/territories/${territoryId}/transactions`);
  }

  getTransaction(id: number): Observable<TerritoryTransaction> {
    return this.http.get<TerritoryTransaction>(`${this.baseUrl}/transactions/${id}`);
  }

  updateTransaction(id: number, transaction: TerritoryTransaction): Observable<TerritoryTransaction> {
    return this.http.put<TerritoryTransaction>(`${this.baseUrl}/transactions/${id}`, transaction);
  }

  deleteTransaction(id: number): Observable<void> {
    return this.http.delete<void>(`${this.baseUrl}/transactions/${id}`);
  }

  getRecentTransactions(): Observable<TerritoryTransaction[]> {
    return this.http.get<TerritoryTransaction[]>(`${this.baseUrl}/transactions/recent`);
  }
}