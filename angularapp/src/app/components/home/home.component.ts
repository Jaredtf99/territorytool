import { Component, OnInit } from '@angular/core';
import { TerritoryService } from '../../shared/territory.service';
import { Territory } from '../../classes/Territory';
import { NgxSpinnerService } from "ngx-spinner";
import { DatePipe } from '@angular/common';
import { Router } from '@angular/router';

@Component({
  selector: 'app-home',
  templateUrl: './home.component.html',
  styleUrls: ['./home.component.css'],
  providers: [DatePipe]
})
export class HomeComponent implements OnInit {
  oldTerritories: Territory[] = [];
  
  constructor(
    private territoryService: TerritoryService,
    private spinner: NgxSpinnerService,
    private datePipe: DatePipe,
    private router: Router
  ) { }

  ngOnInit(): void {
    this.loadOldTerritories();
  }

  private loadOldTerritories(): void {
    this.spinner.show();
    const fourMonthsAgo = new Date();
    fourMonthsAgo.setMonth(fourMonthsAgo.getMonth() - 4);
    
    this.territoryService.getAllTerritories(
      undefined,
      true,
      3,
      undefined,
      undefined,
      fourMonthsAgo
    ).subscribe({
      next: (res) => {
        this.oldTerritories = res;
        this.spinner.hide();
      },
      error: (err) => {
        this.spinner.hide();
        console.error(err);
      }
    });
  }

  getTimeAgo(date: Date): string {
    return this.datePipe.transform(date, 'mediumDate') || '';
  }

  navigateToDetail(id: number): void {
    this.router.navigate(['/territory', id]);
  }
}
