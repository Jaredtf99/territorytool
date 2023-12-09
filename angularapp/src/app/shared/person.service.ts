import { Injectable, Inject } from '@angular/core';
import { HttpClient } from '@angular/common/http'
import { Observable } from 'rxjs';

@Injectable()
export class PersonService {

  constructor(private http: HttpClient, @Inject('BASE_URL') private baseUrl: string) { }

  addPerson(name: string): Observable<any> {
    const body = { name };

    return this.http.post(this.baseUrl + '/persons', body).pipe()
  }

  getAllPersons(): Observable<any> {
    return this.http.get(this.baseUrl + '/persons').pipe()
  }

  deletePerson(name: string): Observable<any> {
    const url = `${this.baseUrl}/persons/${name}`;

    return this.http.delete(url).pipe()
  }

  searchPersons(term: string): Observable<any[]> {
    return this.http.get<any[]>(`${this.baseUrl}/persons/${term}`).pipe()
  }
}
