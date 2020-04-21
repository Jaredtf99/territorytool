import { Component, Inject, ChangeDetectorRef, OnInit, ViewContainerRef } from '@angular/core';
import { FormBuilder, FormGroup, Validators } from '@angular/forms';
import { HttpClient, HttpHeaders } from '@angular/common/http';
import * as InstaScan from 'instascan';
import { isNullOrUndefined } from 'util';
import { ToastrService } from 'ngx-toastr';

declare var $: any;
let qrCodeScanner = this;

@Component({
  selector: 'add-territory',
  templateUrl: './add-territory.component.html',
  styleUrls: ['./add-territory.component.css']
})
export class AddTerritoryComponent implements OnInit {
  addTerritoryForm: FormGroup;
  submitted = false;

  constructor(private cd: ChangeDetectorRef, private formBuilder: FormBuilder, private http: HttpClient, @Inject('BASE_URL') private baseUrl: string, private toastr: ToastrService) {
  }

  ngOnInit() {
    this.addTerritoryForm = this.formBuilder.group({
      code: ['', Validators.required],
      name: ['', Validators.required],
      mapUrl: ['', Validators.required]
    });

  }

  get f() { return this.addTerritoryForm.controls; }


  addTerritory() {
    this.submitted = true;

    if (!this.addTerritoryForm.invalid) {

      let formData = new FormData();
      formData.append('code', this.f.code.value);
      formData.append('name', this.f.name.value);
      formData.append('mapUrl', this.f.mapUrl.value);

      this.http.post(this.baseUrl + 'api/SampleData/AddTerritory', formData).subscribe(() => {
        this.toastr.success('Territorio guardado');
        this.addTerritoryForm.reset();
        this.submitted = false;
      }, error => this.toastr.error(error.error));
    }


  }

  scanQrCode() {
    qrCodeScanner.scanner = new InstaScan.Scanner({ video: document.getElementById('scanner'), mirror: false });

    qrCodeScanner.scanner.addListener('scan', (content) => {
      this.stopQrScanner();
      this.f.mapUrl.setValue(content);
    });

    InstaScan.Camera.getCameras().then(function (cameras) {
      if (cameras.length > 0) {
        qrCodeScanner.scanner.start(cameras[cameras.length - 1]);
      } else {
        console.error('No cameras found.');
      }
    }).catch(function (e) {
      alert(e);
      console.error(e);
    });


  }

  stopQrScanner()
  {
    if (!isNullOrUndefined(qrCodeScanner.scanner)) {
      qrCodeScanner.scanner.stop();
      $('#mi_modal').modal('hide');
    }
  }

}
