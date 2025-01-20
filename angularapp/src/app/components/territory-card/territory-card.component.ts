import { Component, Input, Output, EventEmitter } from "@angular/core"
import { trigger, state, style, transition, animate, keyframes } from "@angular/animations"

@Component({
  selector: "app-territory-card",
  templateUrl: "./territory-card.component.html",
  styleUrls: ["./territory-card.component.scss"],
  animations: [
    trigger("cardHover", [
      state(
        "normal",
        style({
          transform: "translateY(0)",
          boxShadow: "0 2px 4px rgba(0,0,0,0.1)",
        }),
      ),
      state(
        "hovered",
        style({
          transform: "translateY(-8px)",
          boxShadow: "0 12px 24px rgba(108,122,230,0.2)",
        }),
      ),
      transition("normal => hovered", [animate("0.3s cubic-bezier(0.34, 1.56, 0.64, 1)")]),
      transition("hovered => normal", [animate("0.2s cubic-bezier(0.4, 0, 0.2, 1)")]),
    ]),
    trigger("buttonAnimation", [
      transition(":enter", [
        style({ opacity: 0, transform: "scale(0.8)" }),
        animate("0.2s cubic-bezier(0.34, 1.56, 0.64, 1)", style({ opacity: 1, transform: "scale(1)" })),
      ]),
    ]),
  ],
})
export class TerritoryCardComponent {
  @Input() territory: any
  @Output() editClicked = new EventEmitter<any>()
  @Output() deleteClicked = new EventEmitter<any>()
  @Output() cardClicked = new EventEmitter<any>()

  cardState = "normal"
  showButtons = false

  onCardHover() {
    this.cardState = "hovered"
    this.showButtons = true
  }

  onCardLeave() {
    this.cardState = "normal"
    this.showButtons = false
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

