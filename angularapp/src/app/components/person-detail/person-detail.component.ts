import { Component, OnDestroy, OnInit } from '@angular/core';
import { ActivatedRoute, Router } from '@angular/router';
import { Subscription } from 'rxjs';
import { NgxSpinnerService } from 'ngx-spinner';
import { ToastrService } from 'ngx-toastr';
import { PersonService } from '../../shared/person.service';
import { UserService } from '../../shared/user.service';
import { PersonAssignment, PersonDetail, PersonMonthlyActivity } from '../../classes/PersonDetail';
import { PersonExternalInfo } from '../../classes/ExternalExport';
import { DELIVERY_FORMAT_ICONS, DELIVERY_FORMAT_LABELS } from '../../enums/DeliveryFormat';

declare var $: any;

export type HistoryFilter = 'all' | 'ongoing' | 'returned' | 'virtual';

interface HistoryYearGroup {
  year: number;
  items: PersonAssignment[];
}

/** Mismo umbral que la rampa de urgencia de las apps (ámbar → naranja → terracota). */
export function urgencyClass(days: number): 'urgency-low' | 'urgency-mid' | 'urgency-high' {
  if (days < 150) return 'urgency-low';
  if (days < 240) return 'urgency-mid';
  return 'urgency-high';
}

const AVATAR_TINTS = ['tint-green', 'tint-amber', 'tint-terracotta', 'tint-blue'];
const HISTORY_PAGE = 15;

@Component({
  selector: 'person-detail',
  templateUrl: './person-detail.component.html',
  styleUrls: ['./person-detail.component.css']
})
export class PersonDetailComponent implements OnInit, OnDestroy {

  personId!: number;
  detail?: PersonDetail;
  loadError = false;

  readonly deliveryFormatLabels = DELIVERY_FORMAT_LABELS;
  readonly deliveryFormatIcons = DELIVERY_FORMAT_ICONS;
  readonly urgencyClass = urgencyClass;

  readonly historyFilters: { id: HistoryFilter; label: string; icon: string }[] = [
    { id: 'all', label: 'Todos', icon: 'fa-solid fa-layer-group' },
    { id: 'ongoing', label: 'En curso', icon: 'fa-solid fa-person-walking' },
    { id: 'returned', label: 'Devueltos', icon: 'fa-solid fa-check' },
    { id: 'virtual', label: 'Virtuales', icon: DELIVERY_FORMAT_ICONS.virtual }
  ];
  historyFilter: HistoryFilter = 'all';
  historySearch = '';
  historyLimit = HISTORY_PAGE;

  /** Activa la animación de crecimiento de las barras tras el primer render. */
  barsReady = false;
  hoveredMonth: PersonMonthlyActivity | null = null;

  canManage = false;
  editName = '';
  editEnabled = true;
  editExternalId = '';
  editExternalName = '';
  externalNameTaken = false;
  externalIdTaken = false;

  /** Vínculo con NW Scheduler (solo se carga para administradores). */
  external?: PersonExternalInfo;

  private routeSub?: Subscription;

  constructor(
    private route: ActivatedRoute,
    private router: Router,
    private personService: PersonService,
    private userService: UserService,
    private spinner: NgxSpinnerService,
    private toastr: ToastrService
  ) {
    this.canManage = userService.isAdmin() || userService.isSuperAdmin();
  }

  ngOnInit(): void {
    this.routeSub = this.route.params.subscribe(params => {
      this.personId = Number(params['id']);
      this.resetView();
      this.load();
    });
  }

  ngOnDestroy(): void {
    this.routeSub?.unsubscribe();
  }

  // MARK: Carga

  load(showSpinner = true) {
    if (showSpinner) this.spinner.show();
    this.loadError = false;
    this.loadExternal();
    this.personService.getPersonDetail(this.personId).subscribe({
      next: detail => {
        this.detail = detail;
        this.spinner.hide();
        // Un frame después para que la transición de las barras parta de 0.
        setTimeout(() => this.barsReady = true, 60);
      },
      error: err => {
        console.error(err);
        this.spinner.hide();
        this.loadError = true;
        const notFound = String(err?.message ?? '').includes('PERSON_NOT_FOUND');
        this.toastr.error(notFound ? 'Hermano no encontrado' : 'Error cargando la ficha del hermano');
      }
    });
  }

  private loadExternal() {
    if (!this.canManage) return;
    const id = this.personId;
    this.personService.getPersonExternal(id).subscribe({
      next: info => {
        if (this.personId === id) this.external = info;
      },
      error: err => console.error(err)
    });
  }

  private resetView() {
    this.detail = undefined;
    this.external = undefined;
    this.barsReady = false;
    this.historyFilter = 'all';
    this.historySearch = '';
    this.historyLimit = HISTORY_PAGE;
  }

  // MARK: Cabecera

  get initials(): string {
    const parts = (this.detail?.person.name ?? '').trim().split(/\s+/).filter(Boolean);
    if (!parts.length) return '?';
    const first = parts[0][0] ?? '';
    const last = parts.length > 1 ? parts[parts.length - 1][0] : '';
    return (first + last).toUpperCase();
  }

  get avatarTint(): string {
    if (!this.detail?.person.enabled) return 'tint-muted';
    return AVATAR_TINTS[Math.abs(this.personId) % AVATAR_TINTS.length];
  }

  get statusLabel(): string {
    const d = this.detail;
    if (!d) return '';
    if (!d.person.enabled) return 'Inactivo';
    const active = d.summary.activeAssignments;
    if (active === 0) return 'Disponible';
    return active === 1 ? 'Con 1 territorio' : `Con ${active} territorios`;
  }

  get statusClass(): string {
    const d = this.detail;
    if (!d || !d.person.enabled) return 'status-inactive';
    return d.summary.activeAssignments > 0 ? 'status-busy' : 'status-available';
  }

  // MARK: En curso

  /** Porcentaje del ciclo actual frente a la media de la congregación (tope 100). */
  progressFor(days: number): number {
    const avg = this.detail?.summary.congregationAverageHoldingDays || 120;
    return Math.min(100, Math.round((days / avg) * 100));
  }

  // MARK: Actividad

  get activityMax(): number {
    const values = (this.detail?.activity ?? []).flatMap(m => [m.givenCount, m.returnedCount]);
    return Math.max(1, ...values);
  }

  /** Paso "redondo" del eje Y: como mucho ~4 divisiones, siempre enteras. */
  private get axisStep(): number {
    return Math.max(1, Math.ceil(this.activityMax / 4));
  }

  /** Tope del eje Y (múltiplo del paso); las barras se escalan contra él. */
  get axisMax(): number {
    const step = this.axisStep;
    return step * Math.ceil(this.activityMax / step);
  }

  get axisTicks(): number[] {
    const ticks: number[] = [];
    for (let t = 0; t <= this.axisMax; t += this.axisStep) ticks.push(t);
    return ticks;
  }

  tickPosition(tick: number): number {
    return (tick / this.axisMax) * 100;
  }

  get activityTotal(): number {
    return (this.detail?.activity ?? []).reduce((sum, m) => sum + m.givenCount, 0);
  }

  barHeight(value: number): number {
    if (!this.barsReady) return 0;
    if (value === 0) return 0;
    return Math.max(4, Math.round((value / this.axisMax) * 100));
  }

  // MARK: Historial

  get filteredHistory(): PersonAssignment[] {
    const term = normalize(this.historySearch);
    return (this.detail?.history ?? []).filter(item => {
      switch (this.historyFilter) {
        case 'ongoing': if (item.pickedAt) return false; break;
        case 'returned': if (!item.pickedAt) return false; break;
        case 'virtual': if (item.deliveryFormat !== 'virtual') return false; break;
      }
      if (!term) return true;
      return normalize(item.territoryCode).includes(term) || normalize(item.territoryName).includes(term);
    });
  }

  get historyGroups(): HistoryYearGroup[] {
    const groups: HistoryYearGroup[] = [];
    for (const item of this.filteredHistory.slice(0, this.historyLimit)) {
      const year = item.givenAt.getFullYear();
      let group = groups[groups.length - 1];
      if (!group || group.year !== year) {
        group = { year, items: [] };
        groups.push(group);
      }
      group.items.push(item);
    }
    return groups;
  }

  countFor(filter: HistoryFilter): number {
    const history = this.detail?.history ?? [];
    switch (filter) {
      case 'ongoing': return history.filter(h => !h.pickedAt).length;
      case 'returned': return history.filter(h => !!h.pickedAt).length;
      case 'virtual': return history.filter(h => h.deliveryFormat === 'virtual').length;
      default: return history.length;
    }
  }

  setHistoryFilter(filter: HistoryFilter) {
    this.historyFilter = filter;
    this.historyLimit = HISTORY_PAGE;
  }

  onHistorySearch() {
    this.historyLimit = HISTORY_PAGE;
  }

  showMoreHistory() {
    this.historyLimit += HISTORY_PAGE;
  }

  get hasMoreHistory(): boolean {
    return this.filteredHistory.length > this.historyLimit;
  }

  trackByTransaction(_: number, item: { transactionId: number }) {
    return item.transactionId;
  }

  trackByYear(_: number, group: HistoryYearGroup) {
    return group.year;
  }

  // MARK: Navegación y acciones

  openTerritory(territoryId: number) {
    this.router.navigate(['/territory', territoryId]);
  }

  goBack() {
    this.router.navigate(['/persons']);
  }

  giveTerritory() {
    const person = this.detail?.person;
    if (!person) return;
    this.router.navigate(['/change-territory'], { queryParams: { personId: person.id, personName: person.name } });
  }

  openEditModal() {
    if (!this.detail) return;
    this.editName = this.detail.person.name;
    this.editEnabled = this.detail.person.enabled;
    this.editExternalId = this.external?.externalId ?? '';
    this.editExternalName = this.external?.externalName ?? '';
    this.externalIdTaken = false;
    this.externalNameTaken = false;
    $('#editPersonDetailModal').modal('show');
  }

  submitEdit() {
    if (!this.detail || !this.editName.trim()) return;
    this.spinner.show();
    this.personService.updatePerson(this.personId, this.editName.trim(), this.editEnabled).subscribe({
      next: (resp: any) => {
        if (resp?.error) {
          this.spinner.hide();
          this.toastr.error(resp.error.message || 'Error al actualizar el hermano.');
          return;
        }
        this.saveExternalIfChanged();
      },
      error: err => {
        this.spinner.hide();
        this.toastr.error(err?.message || 'Error al actualizar el hermano.');
      }
    });
  }

  /** Tras guardar nombre/estado, guarda el vínculo con NW Scheduler si ha cambiado. */
  private saveExternalIfChanged() {
    const externalId = this.editExternalId.trim() || null;
    // El nombre externo no se recorta: debe coincidir exactamente con NW Scheduler.
    const externalName = this.editExternalName.trim() ? this.editExternalName : null;
    const finish = () => {
      $('#editPersonDetailModal').modal('hide');
      this.toastr.success('Hermano actualizado correctamente.');
      this.load(false);
    };
    if (externalId === (this.external?.externalId ?? null) && externalName === (this.external?.externalName ?? null)) {
      finish();
      return;
    }
    this.personService.setPersonExternal(this.personId, externalId, externalName).subscribe({
      next: () => finish(),
      error: err => {
        this.spinner.hide();
        const message = String(err?.message ?? '');
        this.externalNameTaken = message.includes('EXTERNAL_NAME_ALREADY_USED');
        this.externalIdTaken = message.includes('EXTERNAL_ID_ALREADY_USED');
        if (!this.externalNameTaken && !this.externalIdTaken) {
          this.toastr.error('Se ha guardado el hermano, pero no los datos de NW Scheduler.');
        }
      }
    });
  }

}

function normalize(value: string | undefined): string {
  return (value ?? '').normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase().trim();
}
