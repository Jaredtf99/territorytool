import { Component, Inject } from '@angular/core';
import { HttpClient } from '@angular/common/http';

@Component({
  selector: 'app-fetch-data',
  templateUrl: './fetch-data.component.html'
})
export class FetchDataComponent {
  public territories: Territory[];

  constructor(http: HttpClient, @Inject('BASE_URL') baseUrl: string) {
    http.get<Territory[]>(baseUrl + 'api/SampleData/AllTerritories').subscribe(result => {
      this.territories = result;
    }, error => console.error(error));
  }
}

interface Territory {
  id: number;
  code: string;
  name: string;
  mapUrl: string;
}
