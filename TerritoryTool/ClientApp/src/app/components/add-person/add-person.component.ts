import { Component, OnInit, Inject } from '@angular/core';
import { FormGroup, FormBuilder, Validators } from '@angular/forms';
import { HttpClient } from '@angular/common/http';
import { ToastrService } from 'ngx-toastr';
import { Globals } from '../../globals';

@Component({
  selector: 'app-add-person',
  templateUrl: './add-person.component.html',
  styleUrls: ['./add-person.component.css']
})
export class AddPersonComponent implements OnInit {

  addPersonForm: FormGroup;
  submitted = false;


  constructor(private formBuilder: FormBuilder, private http: HttpClient, @Inject('BASE_URL') private baseUrl: string, private toastr: ToastrService, private globals: Globals) { }

  ngOnInit() {
    this.addPersonForm = this.formBuilder.group({
      name: ['', Validators.required],
    });
  }

  get f() { return this.addPersonForm.controls; }

  addPerson() {
    this.submitted = true;

    if (!this.addPersonForm.invalid) {

      this.globals.loading = true;

      let formData = new FormData();
      formData.append('name', this.f.name.value);

      this.http.post(this.baseUrl + 'api/SampleData/AddPerson', formData).subscribe(() => {
        this.globals.loading = false;
        this.toastr.success('Hermano añadido');
        this.addPersonForm.reset();
        this.submitted = false;
      }, error => {
        this.globals.loading = false;
        this.toastr.error(error.error);
      })
    }


  }

}

