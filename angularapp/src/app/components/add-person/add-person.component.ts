import { Component, Inject } from '@angular/core';
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

  addPersonForm: FormGroup;

  constructor(private fb: FormBuilder, private personService: PersonService, private toastr: ToastrService, private spinner: NgxSpinnerService) {
    this.addPersonForm = this.fb.group({
      name: ['', Validators.required],
    });
  }

  get f() { return this.addPersonForm.controls; }

  addPerson() {

    if (this.addPersonForm.invalid) {
      return;
    }

    this.spinner.show();

    this.personService.addPerson(this.f['name'].value).subscribe({
      next: resp => {
        this.spinner.hide();
        this.toastr.success('Hermano añadido');
        this.addPersonForm.reset();
      },
      error: err => {
        this.spinner.hide();
        this.handleAddError(err);
      }
    });
  }

  private handleAddError(error: any): void {
    if (error.error === "PERSON_ALREADY_EXISTS") {
      this.addPersonForm.get('name')?.setErrors({ personExists: true });
    } else {
      this.toastr.error('Error inesperado');
    }
  }
}

