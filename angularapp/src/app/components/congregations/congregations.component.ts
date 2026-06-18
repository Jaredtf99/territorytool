import { Component, OnInit } from '@angular/core';
import { ToastrService } from 'ngx-toastr';
import { NgxSpinnerService } from 'ngx-spinner';
import { Congregation, CongregationService } from '../../shared/congregation.service';

@Component({
  selector: 'app-congregations',
  templateUrl: './congregations.component.html',
  styleUrls: ['./congregations.component.scss']
})
export class CongregationsComponent implements OnInit {

  congregations: Congregation[] = [];
  newName = '';
  editingId: string | null = null;
  editingName = '';

  constructor(
    public congregationService: CongregationService,
    private toastr: ToastrService,
    private spinner: NgxSpinnerService
  ) { }

  ngOnInit(): void {
    this.load();
  }

  load(): void {
    this.spinner.show();
    this.congregationService.refresh().subscribe({
      next: list => { this.congregations = list; this.spinner.hide(); },
      error: () => { this.spinner.hide(); this.toastr.error('Error al cargar congregaciones'); }
    });
  }

  create(): void {
    const name = this.newName.trim();
    if (!name) return;
    this.spinner.show();
    this.congregationService.createCongregation(name).subscribe({
      next: () => { this.newName = ''; this.toastr.success('Congregación creada'); this.load(); },
      error: err => { this.spinner.hide(); this.toastr.error(this.message(err)); }
    });
  }

  startEdit(c: Congregation): void {
    this.editingId = c.id;
    this.editingName = c.name;
  }

  cancelEdit(): void {
    this.editingId = null;
    this.editingName = '';
  }

  saveEdit(c: Congregation): void {
    const name = this.editingName.trim();
    if (!name || name === c.name) { this.cancelEdit(); return; }
    this.spinner.show();
    this.congregationService.renameCongregation(c.id, name).subscribe({
      next: () => { this.toastr.success('Congregación renombrada'); this.cancelEdit(); this.load(); },
      error: err => { this.spinner.hide(); this.toastr.error(this.message(err)); }
    });
  }

  remove(c: Congregation): void {
    if (!confirm(`¿Eliminar la congregación "${c.name}"? Solo es posible si no tiene territorios ni personas.`)) return;
    this.spinner.show();
    this.congregationService.deleteCongregation(c.id).subscribe({
      next: () => { this.toastr.success('Congregación eliminada'); this.load(); },
      error: err => { this.spinner.hide(); this.toastr.error(this.message(err)); }
    });
  }

  private message(err: any): string {
    const code = err?.message ?? err?.error ?? '';
    if (typeof code === 'string') {
      if (code.includes('CONGREGATION_ALREADY_EXISTS')) return 'Ya existe una congregación con ese nombre';
      if (code.includes('CONGREGATION_NOT_EMPTY')) return 'No se puede eliminar: tiene territorios o personas';
    }
    return 'Error desconocido';
  }
}
