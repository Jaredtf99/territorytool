import { Injectable, Inject } from '@angular/core';
import { HttpClient } from '@angular/common/http'
import { Observable } from 'rxjs';
import { Territory } from '../classes/Territory';


@Injectable()
export class TerritoryService {

  constructor(private http: HttpClient, @Inject('BASE_URL') private baseUrl: string) { }

  editTerritory(id: number, mapUrl:string, name: string, code: string): Observable<any> {
    const body = { id, name, mapUrl, code };

    return this.http.post(this.baseUrl + 'api/SampleData/editTerritory', body).pipe()
  }

  getAllTerritories(): Observable<Territory[]> {
    return this.http.get<Territory[]>(this.baseUrl + 'api/SampleData/AllTerritories').pipe()
  }

  deleteTerritory(id: number): Observable<any> {
    const body = { id };

    return this.http.post(this.baseUrl + 'api/SampleData/deleteTerritory', body).pipe()
  }


}
