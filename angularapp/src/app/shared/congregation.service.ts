import { Injectable } from '@angular/core';
import { BehaviorSubject, from, Observable } from 'rxjs';
import { map, switchMap, tap } from 'rxjs/operators';
import { SupabaseService } from './supabase.service';

export interface Congregation {
  id: string;
  name: string;
  role: string;
  is_active: boolean;
}

@Injectable({ providedIn: 'root' })
export class CongregationService {

  private readonly subject = new BehaviorSubject<Congregation[]>(this.getStored());
  readonly congregations$ = this.subject.asObservable();

  constructor(private supabase: SupabaseService) { }

  private getStored(): Congregation[] {
    try {
      return JSON.parse(localStorage.getItem('congregations') ?? '[]');
    } catch {
      return [];
    }
  }

  private setStored(list: Congregation[]): void {
    localStorage.setItem('congregations', JSON.stringify(list));
    this.subject.next(list);
  }

  getActive(): Congregation | null {
    return this.subject.value.find(c => c.is_active) ?? null;
  }

  hasMultiple(): boolean {
    return this.subject.value.length > 1;
  }

  // Reloads the list of congregations the user can operate in.
  refresh(): Observable<Congregation[]> {
    return from(this.supabase.rpc<Congregation[]>('get_my_congregations')).pipe(
      map(list => list ?? []),
      tap(list => this.setStored(list))
    );
  }

  // --- Superadmin management ---

  createCongregation(name: string): Observable<Congregation> {
    return from(this.supabase.rpc<Congregation>('create_congregation', { p_name: name }));
  }

  renameCongregation(id: string, name: string): Observable<Congregation> {
    return from(this.supabase.rpc<Congregation>('rename_congregation', { p_congregation_id: id, p_name: name }));
  }

  deleteCongregation(id: string): Observable<void> {
    return from(this.supabase.rpc<void>('delete_congregation', { p_congregation_id: id }));
  }

  // Switches the active congregation: persists it, refreshes the JWT so the new
  // congregation_id/app_role claims take effect, then reloads local state.
  switchCongregation(congregationId: string): Observable<string | null> {
    return from(this.supabase.rpc('set_active_congregation', { p_congregation_id: congregationId })).pipe(
      switchMap(() => from(this.supabase.refreshSession())),
      tap(token => {
        if (token) localStorage.setItem('token', token);
        const updated = this.subject.value.map(c => ({ ...c, is_active: c.id === congregationId }));
        this.setStored(updated);
      })
    );
  }
}
