import { Injectable, Inject } from '@angular/core';
import { HttpClient, HttpParams } from '@angular/common/http'
import { Observable } from 'rxjs';
import { Territory } from '../classes/Territory';
import { TerritoryDetail } from '../classes/TerritoryDetail';
import { TerritorySuggestion } from '../classes/TerritorySuggestion';


@Injectable()
export class TerritoryService {

  constructor(private http: HttpClient, @Inject('BASE_URL') private baseUrl: string) { }

  editTerritory(id: number, mapUrl:string, name: string, code: string): Observable<any> {
    const body = { id, mapUrl, name, code };

    return this.http.post(`${this.baseUrl}/territories/${id}`, body).pipe()
  }

  getTerritoryDetailInfo(id: number): Observable<TerritoryDetail> {
    return this.http.get(`${this.baseUrl}/territories/${id}/detail`).pipe()
  }


  getAllTerritories(
    term: string | undefined,
    inUse: boolean | undefined,
    orderByEnum: number | undefined,
    orderAscending: boolean | undefined,
    lastGivenDateFrom: Date | undefined,
    lastGivenDateTo: Date | undefined,
  ): Observable<Territory[]> {

    let params = new HttpParams();

    if (term !== undefined) {
      params = params.set('term', term);
    }

    if (inUse !== undefined) {
      params = params.set('inUse', String(inUse));
    }

    if (orderByEnum !== undefined) {
      params = params.set('orderBy', String(orderByEnum));
    }

    if (orderAscending !== undefined) {
      params = params.set('orderByAscending', String(orderAscending));
    }

    if (lastGivenDateFrom !== undefined) {
      params = params.set('lastGivenDateFrom', lastGivenDateFrom.toISOString());
    }
    if (lastGivenDateTo !== undefined) {
      params = params.set('lastGivenDateTo', lastGivenDateTo.toISOString());
    }


    return this.http.get<Territory[]>(`${this.baseUrl}/territories/all`, { params });  }

  generateExcel(start: Date, end: Date): Observable<Blob> {
    const body = { start, end };

    return this.http.post(`${this.baseUrl}/territories/generate-excel`, body, {
      responseType: 'blob'
    }).pipe()
  }


  deleteTerritory(id: number): Observable<any> {
    const url = `${this.baseUrl}/territories/${id}`;

    return this.http.delete(url).pipe()
  }

  addTerritory(mapUrl: string, name: string, code: string): Observable<any> {
    const body = { mapUrl, name, code };

    return this.http.post(`${this.baseUrl}/territories`, body).pipe()
  }

  searchTerritories(term: string): Observable<Territory[]> {
    return this.http.get<Territory[]>(`${this.baseUrl}/territories?search=${term}`).pipe()
  }

  searchFreeTerritories(term: string, take: number): Observable<Territory[]> {
    return this.http.get<Territory[]>(`${this.baseUrl}/territories?search=${term}&onlyFreeTerritories=true&take=${take}`).pipe()
  }
  searchGivenTerritories(term: string, take: number): Observable<Territory[]> {
    return this.http.get<Territory[]>(`${this.baseUrl}/territories?search=${term}&onlyGivenTerritories=true&take=${take}`).pipe()
  }

  getTerritorySuggestions(): Observable<TerritorySuggestion[]> {
    return this.http.get<TerritorySuggestion[]>(`${this.baseUrl}/territories/give-suggestions`).pipe()
  }

  getTerritoryByMapUrl(mapUrl: string): Observable<Territory> {
    return this.http.get<Territory>(`${this.baseUrl}/territories/map?mapUrl=${encodeURIComponent(mapUrl)}`).pipe()
  }

  getTerritoryByCode(code: string): Observable<Territory> {
    return this.http.get<Territory>(`${this.baseUrl}/territories/code?code=${encodeURIComponent(code)}`).pipe()
  }

  giveTerritory(territoryCode: string, personName: string, isCustomDate: boolean, customDate: Date | undefined): Observable<any> {
    const body = { territoryCode, personName, isCustomDate, customDate };

    return this.http.post(`${this.baseUrl}/territories/give-territory`, body).pipe()
  }

  pickTerritory(territoryCode: string, isCustomDate: boolean, customDate: Date | undefined): Observable<any> {
    const body = { territoryCode, isCustomDate, customDate };

    return this.http.post(`${this.baseUrl}/territories/pick-territory`, body).pipe()
  }

  refreshTerritoryImage(id: number): Observable<any> {
    const url = `${this.baseUrl}/territories/${id}/refresh-image`;

    return this.http.post(url, null).pipe()
  }

  getTerritoryStatistics(territoryId: number) {
    return this.http.get<any>(`${this.baseUrl}/territories/${territoryId}/statistics`);
  }

}
