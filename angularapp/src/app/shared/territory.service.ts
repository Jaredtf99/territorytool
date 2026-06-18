import { Injectable } from '@angular/core';
import { from, Observable } from 'rxjs';
import { map, switchMap } from 'rxjs/operators';
import { Territory } from '../classes/Territory';
import { TerritoryDetail } from '../classes/TerritoryDetail';
import { TerritorySuggestion } from '../classes/TerritorySuggestion';
import { TerritoryInfoTimelineType } from '../enums/TerritoryInfoTimelineType';
import { SupabaseService } from './supabase.service';

@Injectable()
export class TerritoryService {

  constructor(private supabase: SupabaseService) { }

  editTerritory(id: number, mapUrl:string, name: string, code: string): Observable<any> {
    return from(this.supabase.client.rpc('update_territory', {
      territory_id: id,
      map_url: mapUrl,
      name,
      code
    }));
  }

  getTerritoryDetailInfo(id: number): Observable<TerritoryDetail> {
    return from(this.buildTerritoryDetail(id));
  }

  getAllTerritories(
    term: string | undefined,
    inUse: boolean | undefined,
    orderByEnum: number | undefined,
    orderAscending: boolean | undefined,
    lastGivenDateFrom: Date | undefined,
    lastGivenDateTo: Date | undefined,
  ): Observable<Territory[]> {
    return from(this.supabase.client.rpc('search_territories', {
      term: term ?? null,
      only_free: inUse === false,
      only_given: inUse === true,
      take: 1000
    })).pipe(
      switchMap(async (result: any) => {
        if (result.error) throw result.error;
        let territories = await this.mapTerritories(result.data ?? []);
        if (lastGivenDateFrom) {
          territories = territories.filter(t => t.givenDateUtc && new Date(t.givenDateUtc) >= lastGivenDateFrom);
        }
        if (lastGivenDateTo) {
          territories = territories.filter(t => t.givenDateUtc && new Date(t.givenDateUtc) <= lastGivenDateTo);
        }
        return this.sortTerritories(territories, orderByEnum, orderAscending ?? true);
      })
    );
  }

  generateExcel(start: Date, end: Date): Observable<Blob> {
    return from(this.supabase.client.functions.invoke('generate-territory-report', {
      body: { start: start.toISOString(), end: end.toISOString() }
    })).pipe(map((result: any) => {
      if (result.error) throw result.error;
      return result.data as Blob;
    }));
  }

  deleteTerritory(id: number): Observable<any> {
    return from(this.supabase.client.rpc('delete_territory', { territory_id: id }));
  }

  addTerritory(mapUrl: string, name: string, code: string): Observable<any> {
    return from(this.supabase.client.rpc('add_territory', { map_url: mapUrl, name, code }));
  }

  searchTerritories(term: string): Observable<Territory[]> {
    return this.searchTerritoriesInternal(term, false, false);
  }

  searchFreeTerritories(term: string, take: number): Observable<Territory[]> {
    return this.searchTerritoriesInternal(term, true, false, take);
  }

  searchGivenTerritories(term: string, take: number): Observable<Territory[]> {
    return this.searchTerritoriesInternal(term, false, true, take);
  }

  getTerritorySuggestions(): Observable<TerritorySuggestion[]> {
    return from(this.supabase.client.rpc('get_give_suggestions', { count: 3 })).pipe(
      switchMap(async (result: any) => {
        if (result.error) throw result.error;
        const territories = await this.mapTerritories(result.data ?? []);
        return territories.map(t => ({
          id: t.id!,
          code: t.code!,
          name: t.name!,
          mapUrl: t.mapUrl!,
          imgUrl: t.imgUrl!,
          lastPickedDate: t.lastPickedDateUtc!
        }));
      })
    );
  }

  getTerritoryByMapUrl(mapUrl: string): Observable<Territory> {
    return from(this.supabase.client.from('territory_current_state').select('*').eq('map_url', mapUrl).single()).pipe(
      switchMap(async (result: any) => {
        if (result.error) throw result.error;
        return (await this.mapTerritories([result.data]))[0];
      })
    );
  }

  getTerritoryByCode(code: string): Observable<Territory> {
    return from(this.supabase.client.from('territory_current_state').select('*').eq('code', code).single()).pipe(
      switchMap(async (result: any) => {
        if (result.error) throw result.error;
        return (await this.mapTerritories([result.data]))[0];
      })
    );
  }

  giveTerritory(territoryCode: string, personName: string, isCustomDate: boolean, customDate: Date | undefined): Observable<any> {
    return from(this.supabase.client.rpc('give_territory', {
      territory_code: territoryCode,
      person_name: personName,
      custom_date: isCustomDate ? customDate?.toISOString() : null
    }));
  }

  pickTerritory(territoryCode: string, isCustomDate: boolean, customDate: Date | undefined): Observable<any> {
    return from(this.supabase.client.rpc('pick_territory', {
      territory_code: territoryCode,
      custom_date: isCustomDate ? customDate?.toISOString() : null
    }));
  }

  refreshTerritoryImage(id: number): Observable<any> {
    return from(this.supabase.invoke('refresh-territory-image', { territoryId: id }));
  }

  getTerritoryStatistics(territoryId: number) {
    return from(this.supabase.client.rpc('get_territory_statistics', { territory_id: territoryId })).pipe(
      map((result: any) => {
        if (result.error) throw result.error;
        return result.data;
      })
    );
  }

  private searchTerritoriesInternal(term: string, onlyFree: boolean, onlyGiven: boolean, take = 2147483647): Observable<Territory[]> {
    return from(this.supabase.client.rpc('search_territories', {
      term,
      only_free: onlyFree,
      only_given: onlyGiven,
      take
    })).pipe(
      switchMap(async (result: any) => {
        if (result.error) throw result.error;
        return this.mapTerritories(result.data ?? []);
      })
    );
  }

  private async buildTerritoryDetail(id: number): Promise<TerritoryDetail> {
    const [stateResult, historyResult] = await Promise.all([
      this.supabase.client.from('territory_current_state').select('*').eq('id', id).single(),
      this.supabase.client.from('territory_details').select('*').eq('territory_id', id).order('given_at', { ascending: false })
    ]);

    if (stateResult.error) throw stateResult.error;
    if (historyResult.error) throw historyResult.error;

    const territory = (await this.mapTerritories([stateResult.data]))[0];
    // territory_details is built with a LEFT JOIN, so a territory with no
    // transactions still yields one row with all transaction fields null.
    // Drop those phantom rows so we don't render "Entregado a null".
    const history = (historyResult.data ?? []).filter((tx: any) => tx.transaction_id != null);
    return {
      id: territory.id,
      code: territory.code,
      name: territory.name,
      mapUrl: territory.mapUrl,
      imgUrl: territory.imgUrl,
      personName: territory.personName,
      givenDateUtc: territory.givenDateUtc,
      lastPickedDateUtc: territory.lastPickedDateUtc,
      pickedCount: history.filter((tx: any) => tx.picked_at != null).length,
      lastUser: history[0]?.person_name,
      timelineItems: history.flatMap((tx: any) => {
        const items = [{
          id: tx.transaction_id,
          date: tx.given_at,
          description: `Entregado a ${tx.person_name}`,
          type: TerritoryInfoTimelineType.Gave
        }];
        if (tx.picked_at) {
          items.push({
            id: tx.transaction_id,
            date: tx.picked_at,
            description: `Recogido de ${tx.person_name}`,
            type: TerritoryInfoTimelineType.Picked
          });
        }
        return items;
      })
    };
  }

  private async mapTerritories(rows: any[]): Promise<Territory[]> {
    return Promise.all(rows.map(async row => ({
      id: row.id,
      code: row.code,
      name: row.name,
      mapUrl: row.map_url,
      imgUrl: await this.getSignedImageUrl(row.image_path),
      personName: row.person_name,
      givenDateUtc: row.given_at ? new Date(row.given_at) : undefined,
      lastPickedDateUtc: row.last_picked_at ? new Date(row.last_picked_at) : undefined
    })));
  }

  private async getSignedImageUrl(imagePath?: string): Promise<string | undefined> {
    if (!imagePath) return undefined;
    const { data } = await this.supabase.client.storage
      .from('territory-images')
      .createSignedUrl(imagePath, 60 * 60);
    return data?.signedUrl;
  }

  private sortTerritories(territories: Territory[], orderByEnum: number | undefined, ascending: boolean): Territory[] {
    if (orderByEnum === undefined) return territories;
    const direction = ascending ? 1 : -1;
    return territories.sort((a, b) => {
      if (orderByEnum === 1) return String(a.name ?? '').localeCompare(String(b.name ?? '')) * direction;
      if (orderByEnum === 2) return String(a.code ?? '').localeCompare(String(b.code ?? '')) * direction;
      if (orderByEnum === 3) return ((a.givenDateUtc?.getTime() ?? 0) - (b.givenDateUtc?.getTime() ?? 0)) * direction;
      return 0;
    });
  }
}
