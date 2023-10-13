import { Component, OnInit, Inject } from '@angular/core';
import { FormGroup, FormBuilder, Validators } from '@angular/forms';
import { ToastrService } from 'ngx-toastr';
import { PersonService } from '../../shared/person.service';
import { NgxSpinnerService } from "ngx-spinner";

@Component({
  selector: 'app-add-person',
  templateUrl: './add-person.component.html',
  styleUrls: ['./add-person.component.css']
})
export class AddPersonComponent {

  addPersonForm!: FormGroup;
  submitted = false;


  constructor(private fb: FormBuilder, private personService: PersonService, private toastr: ToastrService, private spinner: NgxSpinnerService) {

    this.addPersonForm = this.fb.group({
      name: ['', Validators.required],
    });

  }


  get f() { return this.addPersonForm.controls; }

  addPerson() {
    this.submitted = true;

    if (!this.addPersonForm.invalid) {

      this.spinner.show();

      this.personService.addPerson(this.f['name'].value)
        .subscribe({
          next: resp => {
            this.spinner.hide();
            this.toastr.success('Hermano añadido');
            this.addPersonForm.reset();
            this.submitted = false;
          },
          error: err => {
            this.spinner.hide();
            this.toastr.error('Error inesperado');
          }
        });
    }


  }

}

