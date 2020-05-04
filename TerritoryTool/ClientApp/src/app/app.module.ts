import { BrowserModule } from '@angular/platform-browser';
import { NgModule } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { HttpClientModule, HTTP_INTERCEPTORS } from '@angular/common/http';
import { RouterModule } from '@angular/router';
import { AppComponent } from './app.component';
import { NavMenuComponent } from './components/nav-menu/nav-menu.component';
import { HomeComponent } from './components/home/home.component';
import { TerritoriesComponent } from './components/territories/territories.component';
import { AddTerritoryComponent } from './components/add-territory/add-territory.component';
import { ReactiveFormsModule } from '@angular/forms';
import { BrowserAnimationsModule } from '@angular/platform-browser/animations';
import { ToastrModule } from 'ngx-toastr';
import { RegistrationComponent } from './components/registration/registration.component';
import { UserService } from './shared/user.service';
import { LoginComponent } from './components/login/login.component';
import { LoggedComponent } from './components/logged/logged.component';
import { AuthGuard } from './auth/auth.guard';
import { AuthInterceptor } from './auth/auth.interceptor';
import { ForbiddenComponent } from './components/forbidden/forbidden.component';
import { ViewActionlogsComponent } from './components/view-actionlogs/view-actionlogs.component';
import { UserConfigurationComponent } from './components/user-configuration/user-configuration.component';
import { NgxLoadingModule } from 'ngx-loading';
import { Globals } from './globals';
import { UsersComponent } from './components/users/users.component';
import { SelectorComponent } from './components/selector/selector.component';


@NgModule({
  declarations: [
    AppComponent,
    NavMenuComponent,
    HomeComponent,
    TerritoriesComponent,
    AddTerritoryComponent,
    RegistrationComponent,
    LoginComponent,
    LoggedComponent,
    ForbiddenComponent,
    ViewActionlogsComponent,
    UserConfigurationComponent,
    UsersComponent,
    SelectorComponent
  ],
  imports: [
    BrowserModule.withServerTransition({ appId: 'ng-cli-universal' }),
    BrowserAnimationsModule,
    HttpClientModule,
    FormsModule,
    ReactiveFormsModule,
    NgxLoadingModule.forRoot({}),
    RouterModule.forRoot([
      {
        path: '', component: LoggedComponent, canActivateChild: [AuthGuard], children: [
          { path: 'home', component: HomeComponent, },
          { path: 'territories', component: TerritoriesComponent },
          { path: 'add-territory', component: AddTerritoryComponent, data: {permittedRoles:['SUPERADMIN', 'ADMIN']} },
          { path: 'registration', component: RegistrationComponent, data: { permittedRoles: ['SUPERADMIN', 'ADMIN'] } },
          { path: 'user-configuration', component: UserConfigurationComponent },
          { path: 'action-logs', component: ViewActionlogsComponent, data: { permittedRoles: ['SUPERADMIN'] } },
          { path: 'users', component: UsersComponent, data: { permittedRoles: ['SUPERADMIN', 'ADMIN'] } }
        ]
      },
      { path: 'login', component: LoginComponent },
      { path: 'forbidden', component: ForbiddenComponent }
    ]),
    ToastrModule.forRoot({
      timeOut: 2000,
      preventDuplicates: false,
    })
  ],
  providers: [UserService, AuthGuard, {
    provide: HTTP_INTERCEPTORS,
    useClass: AuthInterceptor,
    multi: true
  }, Globals],
  bootstrap: [AppComponent]
})
export class AppModule { }
