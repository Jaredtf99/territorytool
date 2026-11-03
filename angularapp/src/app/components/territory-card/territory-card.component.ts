import { Component, Input, Output, EventEmitter } from "@angular/core"
import { Territory } from "src/app/classes/Territory"
import { DELIVERY_FORMAT_ICONS, DELIVERY_FORMAT_LABELS } from "src/app/enums/DeliveryFormat"

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

  readonly deliveryFormatLabels = DELIVERY_FORMAT_LABELS
  readonly deliveryFormatIcons = DELIVERY_FORMAT_ICONS

  get isOldDate(): boolean {
    if (!this.territory.givenDateUtc) return false;
    const fourMonthsAgo = new Date();
    fourMonthsAgo.setMonth(fourMonthsAgo.getMonth() - 4);
    return new Date(this.territory.givenDateUtc) < fourMonthsAgo;
  }

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

