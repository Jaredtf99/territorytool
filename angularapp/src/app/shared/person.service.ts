import { Injectable, Inject } from '@angular/core';
import { HttpClient } from '@angular/common/http'
import { Observable } from 'rxjs';

@Injectable()
export class PersonService {

  constructor(private http: HttpClient, @Inject('BASE_URL') private baseUrl: string) { }

  addPerson(name: string): Observable<any> {
    const body = { name };

    return this.http.post(this.baseUrl + 'api/SampleData/AddPerson', body).pipe()
  }

  getAllPersons(): Observable<any> {
    const body = { name };

    return this.http.get(this.baseUrl + 'api/SampleData/GetAllPersons').pipe()
  }

  deletePerson(name: string): Observable<any> {
    const body = { name };

    return this.http.post(this.baseUrl + 'api/SampleData/DeletePerson', body).pipe()
  }


}
