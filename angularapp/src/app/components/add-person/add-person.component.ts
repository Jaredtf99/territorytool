import { Component, OnInit, Inject } from '@angular/core';
import { FormGroup, FormBuilder, Validators } from '@angular/forms';
import { HttpClient } from '@angular/common/http';
import { ToastrService } from 'ngx-toastr';
import { Globals } from '../../globals';
import { PersonService } from '../../shared/person.service';

@Component({
  selector: 'app-add-person',
  templateUrl: './add-person.component.html',
  styleUrls: ['./add-person.component.css']
})
export class AddPersonComponent {

  addPersonForm!: FormGroup;
  submitted = false;


  constructor(private fb: FormBuilder, private personService: PersonService, private toastr: ToastrService, private globals: Globals) {

    this.addPersonForm = this.fb.group({
      name: ['', Validators.required],
    });

  }


  get f() { return this.addPersonForm.controls; }

  addPerson() {
    this.submitted = true;

    if (!this.addPersonForm.invalid) {

      this.globals.loading = true;

      this.personService.addPerson(this.f['name'].value)
        .subscribe({
          next: resp => {
            this.globals.loading = false;
            this.toastr.success('Hermano añadido');
            this.addPersonForm.reset();
            this.submitted = false;
          },
          error: err => {
            this.globals.loading = false;
            this.toastr.error('Error inesperado');
          }
        });
    }


  }

}

