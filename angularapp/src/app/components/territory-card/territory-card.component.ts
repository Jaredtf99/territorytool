import { Component, Input, Output, EventEmitter } from "@angular/core"
import { Territory } from "src/app/classes/Territory"

@Component({
  selector: "app-territory-card",
  templateUrl: "./territory-card.component.html",
  styleUrls: ["./territory-card.component.scss"]
})
export class TerritoryCardComponent {
  @Input() territory!: Territory
  @Output() editClicked = new EventEmitter<any>()
  @Output() deleteClicked = new EventEmitter<any>()
  @Output() cardClicked = new EventEmitter<any>()


  onEditClick(event: Event) {
    event.stopPropagation()
    this.editClicked.emit(this.territory)
  }

  onDeleteClick(event: Event) {
    event.stopPropagation()
    this.deleteClicked.emit(this.territory.id)
  }

  onCardClick() {
    this.cardClicked.emit(this.territory.id)
  }
}

