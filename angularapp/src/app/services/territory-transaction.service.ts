import { Injectable } from '@angular/core';
import { from, Observable } from 'rxjs';
import { map } from 'rxjs/operators';
import { TerritoryTransaction } from '../classes/territory-transaction.model';
import { SupabaseService } from '../shared/supabase.service';

@Injectable()
export class TerritoryTransactionService {

  constructor(private supabase: SupabaseService) { }

  getTransactions(territoryId: number): Observable<TerritoryTransaction[]> {
    return from(this.supabase.client.from('territory_details').select('*').eq('territory_id', territoryId).order('given_at', { ascending: false })).pipe(
      map((result: any) => {
        if (result.error) throw result.error;
        // territory_details LEFT-joins transactions, so a territory with no
        // transactions returns one phantom row with null fields. Filter it out.
        return result.data
          .filter((row: any) => row.transaction_id != null)
          .map((row: any) => this.mapTransaction(row));
      })
    );
  }

  getTransaction(id: number): Observable<TerritoryTransaction> {
    return from(this.supabase.client.from('territory_details').select('*').eq('transaction_id', id).single()).pipe(
      map((result: any) => {
        if (result.error) throw result.error;
        return this.mapTransaction(result.data);
      })
    );
  }

  updateTransaction(id: number, transaction: TerritoryTransaction): Observable<TerritoryTransaction> {
    return from(this.supabase.client.rpc('update_transaction', {
      transaction_id: id,
      person_id: transaction.personId,
      given_at: transaction.givenDateUtc,
      picked_at: transaction.pickedDateUtc ?? null
    })).pipe(map((result: any) => {
      if (result.error) throw result.error;
      return {
        ...transaction,
        transactionId: result.data.id,
        territoryId: result.data.territory_id,
        personId: result.data.person_id,
        givenDateUtc: new Date(result.data.given_at),
        pickedDateUtc: result.data.picked_at ? new Date(result.data.picked_at) : undefined
      };
    }));
  }

  deleteTransaction(id: number): Observable<void> {
    return from(this.supabase.client.rpc('delete_transaction', { transaction_id: id })).pipe(
      map((result: any) => {
        if (result.error) throw result.error;
      })
    );
  }

  getRecentTransactions(): Observable<TerritoryTransaction[]> {
    return from(this.supabase.client.from('recent_transactions').select('*').order('given_at', { ascending: false })).pipe(
      map((result: any) => {
        if (result.error) throw result.error;
        return result.data.map((row: any) => this.mapTransaction(row));
      })
    );
  }

  private mapTransaction(row: any): TerritoryTransaction {
    return {
      transactionId: row.transaction_id,
      territoryId: row.territory_id,
      personId: row.person_id,
      personName: row.person_name,
      territoryName: row.territory_name ?? row.name,
      givenDateUtc: new Date(row.given_at),
      isAutomaticGivenDate: row.is_automatic_given_date ?? false,
      givenBy: row.given_by_username,
      pickedDateUtc: row.picked_at ? new Date(row.picked_at) : undefined,
      isAutomaticPickedDate: row.is_automatic_picked_date ?? undefined,
      pickedBy: row.picked_by_username
    };
  }
}
