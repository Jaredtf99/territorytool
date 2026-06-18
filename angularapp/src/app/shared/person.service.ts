import { Injectable } from '@angular/core';
import { from } from 'rxjs';
import { Observable } from 'rxjs';
import { map } from 'rxjs/operators';
import { SupabaseService } from './supabase.service';

@Injectable()
export class PersonService {

  constructor(private supabase: SupabaseService) { }

  addPerson(name: string): Observable<any> {
    return from(this.supabase.client.rpc('add_person', { name }));
  }

  getAllPersons(): Observable<any> {
    return from(this.supabase.client
      .from('persons')
      .select('id, name, enabled, territoriesInUse:territory_transactions(territory:territories(name, code), given_at, picked_at)')
      .order('name')).pipe(
        map((result: any) => {
          if (result.error) throw result.error;
          return result.data.map((person: any) => ({
            id: person.id,
            name: person.name,
            enabled: person.enabled,
            territoriesInUse: (person.territoriesInUse ?? [])
              .filter((tx: any) => tx.picked_at == null)
              .map((tx: any) => ({
                territoryName: tx.territory?.name,
                territoryCode: tx.territory?.code,
                givenDate: tx.given_at
              }))
          }));
        })
      );
  }

  deletePerson(name: string): Observable<any> {
    return from(this.supabase.client.rpc('delete_person', { name }));
  }

  searchPersons(term: string, take: number): Observable<any[]> {
    return from(this.supabase.client.rpc('search_persons', { term, take })).pipe(
      map((result: any) => {
        if (result.error) throw result.error;
        return result.data.map((person: any) => ({
          id: person.id,
          name: person.name,
          enabled: person.enabled
        }));
      })
    );
  }

  updatePerson(id: number, name: string, enabled: boolean): Observable<any> {
    return from(this.supabase.client.rpc('update_person', { person_id: id, name, enabled }));
  }
}
