import { Component, OnInit, Inject } from '@angular/core';
import { FormGroup, FormBuilder, Validators } from '@angular/forms';
import { ToastrService } from 'ngx-toastr';
import { PersonService } from '../../shared/person.service';
import { NgxSpinnerService } from "ngx-spinner";
import { ActivatedRoute } from '@angular/router';
import { TerritoryService } from '../../shared/territory.service';
import { Territory } from '../../classes/Territory';
import { TerritoryDetail } from '../../classes/TerritoryDetail';

@Component({
  selector: 'territory-detail',
  templateUrl: './territory-detail.component.html',
  styleUrls: ['./territory-detail.component.css']
})
export class TerritoryDetailComponent implements OnInit {

  territoryId!: number;
  territoryInfo: TerritoryDetail | undefined;


  constructor(private route: ActivatedRoute, public territoryService: TerritoryService, private toastr: ToastrService, private spinner: NgxSpinnerService) {

  }

  ngOnInit(): void {
    this.route.params.subscribe(params => {
      this.territoryId = params['id'];

      this.territoryService.getTerritoryDetailInfo(this.territoryId).subscribe(
        {
          next: res => {
            this.territoryInfo = res
            this.territoryInfo.timelineItems!.sort((a: any, b: any) => {
              return new Date(b.date).getTime() - new Date(a.date).getTime();
            });
            this.spinner.hide();
          },
          error: err => {
            this.spinner.hide();
            console.error(err);
          }
        });

    });
  }

}

