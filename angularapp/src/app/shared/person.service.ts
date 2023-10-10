import { Injectable, Inject } from '@angular/core';
import { HttpClient } from '@angular/common/http'
import { Observable, catchError, throwError } from 'rxjs';
import { ToastrService } from 'ngx-toastr';
import { Globals } from '../globals';


@Injectable()
export class PersonService {

  constructor(private http: HttpClient, @Inject('BASE_URL') private baseUrl: string, private globals: Globals, private toastr: ToastrService) { }

  addPerson(name: string): Observable<any> {
    const body = { name };

    return this.http.post(this.baseUrl + 'api/SampleData/AddPerson', body).pipe()
  }

  getAllPersons(): Observable<any> {
    const body = { name };

    return this.http.get(this.baseUrl + 'api/SampleData/GetAllPersons').pipe()
  }


}
