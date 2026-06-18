import { BrowserModule } from '@angular/platform-browser';
import { NgModule } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { RouterModule } from '@angular/router';
import { NgxSpinnerModule } from "ngx-spinner";
import { CollapseModule } from 'ngx-bootstrap/collapse';
import { NgxScannerQrcodeModule, LOAD_WASM } from 'ngx-scanner-qrcode';

import { UserService } from './shared/user.service';
import { PersonService } from './shared/person.service';
import { TerritoryService } from './shared/territory.service';
import { TerritoryTransactionService } from './services/territory-transaction.service';

import { AppComponent } from './app.component';
import { HomeComponent } from './components/home/home.component';
import { TerritoriesComponent } from './components/territories/territories.component';
import { ReactiveFormsModule } from '@angular/forms';
import { BrowserAnimationsModule } from '@angular/platform-browser/animations';
import { ToastrModule } from 'ngx-toastr';
import { RegistrationComponent } from './components/registration/registration.component';
import { LoginComponent } from './components/login/login.component';
import { LoggedComponent } from './components/logged/logged.component';
import { AuthGuard } from './auth/auth.guard';
import { ForbiddenComponent } from './components/forbidden/forbidden.component';
import { ViewActionlogsComponent } from './components/view-actionlogs/view-actionlogs.component';
import { UserConfigurationComponent } from './components/user-configuration/user-configuration.component';
import { Globals } from './globals';
import { UsersComponent } from './components/users/users.component';
import { AddPersonComponent } from './components/add-person/add-person.component';
import { PersonsComponent } from './components/persons/persons.component';
import { SidebarComponent } from './components/sidebar/sidebar.component';
import { NavbarComponent } from './components/navbar/navbar.component';
import { AddTerritoryComponent } from './components/add-territory/add-territory.component';
import { ChangeTerritoryComponent } from './components/change-territory/change-territory.component';
import { PickTerritoryComponent } from './components/pick-territory/pick-territory.component';
import { GenerateReportComponent } from './components/generate-report/generate-report.component';
import { NgSelectModule } from '@ng-select/ng-select';
import { TimeagoModule, TimeagoIntl, TimeagoFormatter, TimeagoCustomFormatter } from "ngx-timeago";

import { EditTerritoryModalComponent } from './components/edit-territory-modal/edit-territory-modal.component';
import { DeleteTerritoryModalComponent } from './components/delete-territory-modal/delete-territory-modal.component';
import { TerritoryDetailComponent } from './components/territory-detail/territory-detail.component';
import { TerritoryTransactionsComponent } from './components/territory-transactions/territory-transactions.component';
import { EditTransactionModalComponent } from './components/edit-transaction-modal/edit-transaction-modal.component';
import { TerritoryCardComponent } from './components/territory-card/territory-card.component';
import { RecentTransactionsComponent } from './components/recent-transactions/recent-transactions.component';
import { CongregationsComponent } from './components/congregations/congregations.component';

LOAD_WASM().subscribe((res: any) => console.log('LOAD_WASM', res));

export class MyIntl extends TimeagoIntl {
  // do extra stuff here...
}

@NgModule({
  declarations: [
    AppComponent,
    HomeComponent,
    TerritoriesComponent,
    RegistrationComponent,
    LoginComponent,
    LoggedComponent,
    ForbiddenComponent,
    ViewActionlogsComponent,
    UserConfigurationComponent,
    UsersComponent,
    AddPersonComponent,
    PersonsComponent,
    SidebarComponent,
    NavbarComponent,
    AddTerritoryComponent,
    ChangeTerritoryComponent,
    PickTerritoryComponent,
    GenerateReportComponent,
    EditTerritoryModalComponent,
    TerritoryCardComponent,
    DeleteTerritoryModalComponent,
    TerritoryDetailComponent,
    TerritoryTransactionsComponent,
    EditTransactionModalComponent,
    RecentTransactionsComponent,
    CongregationsComponent,
  ],
  imports: [
    BrowserModule.withServerTransition({ appId: 'ng-cli-universal' }),
    BrowserAnimationsModule,
    FormsModule,
    ReactiveFormsModule,
    NgxSpinnerModule,
    NgSelectModule,
    RouterModule.forRoot([
      {
        path: '', component: LoggedComponent, canActivateChild: [AuthGuard], children: [
          { path: 'home', component: HomeComponent, },
          { path: 'territories', component: TerritoriesComponent },
          { path: 'territory/:id', component: TerritoryDetailComponent },
          { path: 'territory/:id/transactions', component: TerritoryTransactionsComponent },
          { path: 'recent-transactions', component: RecentTransactionsComponent },
          { path: 'add-territory', component: AddTerritoryComponent, data: { permittedRoles: ['SUPERADMIN', 'ADMIN'] } },
          { path: 'change-territory', component: ChangeTerritoryComponent },
          { path: 'change-territory/:territoryCode', component: ChangeTerritoryComponent },
          { path: 'pick-territory', component: PickTerritoryComponent },
          { path: 'pick-territory/:territoryCode', component: PickTerritoryComponent },
          { path: 'generate-report', component: GenerateReportComponent },
          { path: 'registration', component: RegistrationComponent, data: { permittedRoles: ['SUPERADMIN', 'ADMIN'] } },
          { path: 'user-configuration', component: UserConfigurationComponent },
          { path: 'action-logs', component: ViewActionlogsComponent, data: { permittedRoles: ['SUPERADMIN'] } },
          { path: 'users', component: UsersComponent, data: { permittedRoles: ['SUPERADMIN', 'ADMIN'] } },
          { path: 'congregations', component: CongregationsComponent, data: { permittedRoles: ['SUPERADMIN'] } },
          { path: 'add-person', component: AddPersonComponent, data: { permittedRoles: ['SUPERADMIN', 'ADMIN'] } },
          { path: 'persons', component: PersonsComponent }

        ]
      },
      { path: 'login', component: LoginComponent },
      { path: 'forbidden', component: ForbiddenComponent }
    ]),
    ToastrModule.forRoot({
      timeOut: 2000,
      preventDuplicates: false,
    }),
    CollapseModule.forRoot(),
    NgxScannerQrcodeModule,
    TimeagoModule.forRoot({
      intl: { provide: TimeagoIntl, useClass: MyIntl },
      formatter: { provide: TimeagoFormatter, useClass: TimeagoCustomFormatter },
    }),
  ],
  providers: [UserService, PersonService, TerritoryService, TerritoryTransactionService, AuthGuard, Globals],
  bootstrap: [AppComponent]
})
export class AppModule { }
