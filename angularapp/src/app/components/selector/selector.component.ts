import { Component, OnInit, Input, Output, EventEmitter } from '@angular/core';

@Component({
  selector: 'app-selector',
  templateUrl: './selector.component.html',
  styleUrls: ['./selector.component.css']
})
export class SelectorComponent {

  @Input()
  options!: string[];
  @Input()
  default!: number;

  ngOnInit() {
    this.selectedRadioButtonChanged(this.default);
  }

  @Output()
  selectionChanged: EventEmitter<number> = new EventEmitter<number>();


  selectedRadioButtonChanged(selectedIndex: number) {
    this.selectionChanged.emit(selectedIndex);
  }  

}
