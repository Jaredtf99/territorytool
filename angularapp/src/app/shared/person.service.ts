import { Injectable } from '@angular/core';
import { from } from 'rxjs';
import { Observable } from 'rxjs';
import { map } from 'rxjs/operators';
import { SupabaseService } from './supabase.service';
import { PersonDetail } from '../classes/PersonDetail';
import { PersonExternalInfo } from '../classes/ExternalExport';
import { parseDeliveryFormat } from '../enums/DeliveryFormat';

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

  /** ID y nombre del hermano en NW Scheduler. */
  getPersonExternal(id: number): Observable<PersonExternalInfo> {
    return from(this.supabase.client
      .from('persons')
      .select('external_id, external_name')
      .eq('id', id)
      .single()).pipe(
        map((result: any) => {
          if (result.error) throw result.error;
          return {
            externalId: result.data?.external_id ?? null,
            externalName: result.data?.external_name ?? null
          };
        })
      );
  }

  /** Vacío = desvincular. El nombre se guarda tal cual (NW Scheduler exige coincidencia exacta). */
  setPersonExternal(id: number, externalId: string | null, externalName: string | null): Observable<void> {
    return from(this.supabase.client.rpc('set_person_external', {
      p_person_id: id,
      p_external_id: externalId,
      p_external_name: externalName
    })).pipe(
      map((result: any) => {
        if (result.error) throw result.error;
      })
    );
  }

  /** Ficha completa del hermano (perfil, resumen, en curso, actividad e historial). */
  getPersonDetail(id: number): Observable<PersonDetail> {
    const timezone = Intl.DateTimeFormat().resolvedOptions().timeZone || 'UTC';
    return from(this.supabase.client.rpc('get_person_detail', { p_person_id: id, p_timezone: timezone })).pipe(
      map((result: any) => {
        if (result.error) throw result.error;
        return mapPersonDetail(result.data);
      })
    );
  }
}

const toDate = (value: any): Date | undefined => (value ? new Date(value) : undefined);
const toNumber = (value: any): number | null => (value == null ? null : Number(value));

function mapPersonDetail(raw: any): PersonDetail {
  const summary = raw?.summary ?? {};
  return {
    generatedAt: toDate(raw?.generatedAt) ?? new Date(),
    person: {
      id: raw?.person?.id,
      name: raw?.person?.name ?? '',
      enabled: raw?.person?.enabled !== false,
      createdAt: toDate(raw?.person?.createdAt)
    },
    summary: {
      totalAssignments: summary.totalAssignments ?? 0,
      activeAssignments: summary.activeAssignments ?? 0,
      completedAssignments: summary.completedAssignments ?? 0,
      uniqueTerritories: summary.uniqueTerritories ?? 0,
      virtualAssignments: summary.virtualAssignments ?? 0,
      averageHoldingDays: toNumber(summary.averageHoldingDays),
      congregationAverageHoldingDays: toNumber(summary.congregationAverageHoldingDays),
      longestHoldingDays: toNumber(summary.longestHoldingDays),
      firstAssignmentAt: toDate(summary.firstAssignmentAt),
      lastAssignmentAt: toDate(summary.lastAssignmentAt),
      lastReturnAt: toDate(summary.lastReturnAt),
      assignmentsLastYear: summary.assignmentsLastYear ?? 0,
      activityRank: toNumber(summary.activityRank),
      activePersonsCount: summary.activePersonsCount ?? 0
    },
    current: (raw?.current ?? []).map((tx: any) => ({
      transactionId: tx.transactionId,
      territoryId: tx.territoryId,
      territoryCode: tx.territoryCode,
      territoryName: tx.territoryName,
      givenAt: new Date(tx.givenAt),
      days: tx.days ?? 0,
      deliveryFormat: parseDeliveryFormat(tx.deliveryFormat),
      givenBy: tx.givenBy ?? undefined
    })),
    activity: (raw?.activity ?? []).map((m: any) => ({
      // `YYYY-MM-DD` sin hora: se construye en local para no saltar de mes por la zona.
      month: new Date(`${m.month}T00:00:00`),
      givenCount: m.givenCount ?? 0,
      returnedCount: m.returnedCount ?? 0
    })),
    topTerritories: (raw?.topTerritories ?? []).map((t: any) => ({
      territoryId: t.territoryId,
      territoryCode: t.territoryCode,
      territoryName: t.territoryName,
      times: t.times ?? 0,
      totalDays: t.totalDays ?? 0,
      lastGivenAt: toDate(t.lastGivenAt)
    })),
    history: (raw?.history ?? []).map((tx: any) => ({
      transactionId: tx.transactionId,
      territoryId: tx.territoryId,
      territoryCode: tx.territoryCode,
      territoryName: tx.territoryName,
      givenAt: new Date(tx.givenAt),
      pickedAt: toDate(tx.pickedAt),
      days: tx.days ?? 0,
      deliveryFormat: parseDeliveryFormat(tx.deliveryFormat),
      givenBy: tx.givenBy ?? undefined,
      pickedBy: tx.pickedBy ?? undefined
    }))
  };
}
