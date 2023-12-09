import { Injectable, Inject } from '@angular/core';
import { HttpClient } from '@angular/common/http'
import { Observable } from 'rxjs';
import { Territory } from '../classes/Territory';


@Injectable()
export class TerritoryService {

  constructor(private http: HttpClient, @Inject('BASE_URL') private baseUrl: string) { }

  editTerritory(id: number, mapUrl:string, name: string, code: string): Observable<any> {
    const body = { id, mapUrl, name, code };

    return this.http.post(`${this.baseUrl}/territories/${id}`, body).pipe()
  }

  getAllTerritories(): Observable<Territory[]> {
    return this.http.get<Territory[]>(`${this.baseUrl}/territories/all`).pipe()
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

  searchFreeTerritories(term: string): Observable<Territory[]> {
    return this.http.get<Territory[]>(`${this.baseUrl}/territories?search=${term}&onlyFreeTerritories=true`).pipe()
  }

  giveTerritory(territoryCode: string, personName: string, isCustomDate: boolean, customDate: Date | undefined): Observable<any> {
    const body = { territoryCode, personName, isCustomDate, customDate };

    return this.http.post(`${this.baseUrl}/territories/give-territory`, body).pipe()
  }


}
