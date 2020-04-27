import { BrowserModule } from '@angular/platform-browser';
import { NgModule } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { HttpClientModule, HTTP_INTERCEPTORS } from '@angular/common/http';
import { RouterModule } from '@angular/router';
import { AppComponent } from './app.component';
import { NavMenuComponent } from './nav-menu/nav-menu.component';
import { HomeComponent } from './home/home.component';
import { CounterComponent } from './counter/counter.component';
import { TerritoriesComponent } from './territories/territories.component';
import { AddTerritoryComponent } from './add-territory/add-territory.component';
import { ReactiveFormsModule } from '@angular/forms';
import { BrowserAnimationsModule } from '@angular/platform-browser/animations';
import { ToastrModule } from 'ngx-toastr';
import { RegistrationComponent } from './registration/registration.component';
import { UserService } from './shared/user.service';
import { LoginComponent } from './login/login.component';
import { LoggedComponent } from './logged/logged.component';
import { AuthGuard } from './auth/auth.guard';
import { AuthInterceptor } from './auth/auth.interceptor';
import { ForbiddenComponent } from './forbidden/forbidden.component';

@NgModule({
  declarations: [
    AppComponent,
    NavMenuComponent,
    HomeComponent,
    CounterComponent,
    TerritoriesComponent,
    AddTerritoryComponent,
    RegistrationComponent,
    LoginComponent,
    LoggedComponent,
    ForbiddenComponent
  ],
  imports: [
    BrowserModule.withServerTransition({ appId: 'ng-cli-universal' }),
    BrowserAnimationsModule,
    HttpClientModule,
    FormsModule,
    ReactiveFormsModule,
    RouterModule.forRoot([
      {
        path: '', component: LoggedComponent, canActivateChild: [AuthGuard], children: [
          { path: 'home', component: HomeComponent, },
          { path: 'counter', component: CounterComponent },
          { path: 'territories', component: TerritoriesComponent },
          { path: 'add-territory', component: AddTerritoryComponent, data: {permittedRoles:['SUPERADMIN', 'ADMIN']} },
          { path: 'registration', component: RegistrationComponent, data: { permittedRoles: ['SUPERADMIN', 'ADMIN'] } }
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
  }],
  bootstrap: [AppComponent]
})
export class AppModule { }
