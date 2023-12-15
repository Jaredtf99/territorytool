import { Injectable } from '@angular/core';

@Injectable({
  providedIn: 'root'
})
export class AppService {

  isSidebarPinned = false;
  isSidebarToggeled = false;

  constructor() { }

  toggleSidebar() {
    this.isSidebarToggeled = !this.isSidebarToggeled;
  }

  toggleSidebarPin() {
    this.isSidebarPinned = !this.isSidebarPinned;
  }

  getSidebarStat() {
    return {
      isSidebarPinned: this.isSidebarPinned,
      isSidebarToggeled: this.isSidebarToggeled
    }
  }

  /**
   * Hace un clear del input de texto del NgSelect.
   * Es necesario en los [editableSearchTerm] true debido a un bug de la libreria
   * @param idNgSelect ID del elemento ng-select
   * @returns
   */
  clearSearchTextFromNgSelect(idNgSelect: string) {
    if (idNgSelect == null) return;

    let ngSelectElement = document.getElementById(idNgSelect);

    if (ngSelectElement) {
      let input = ngSelectElement.querySelector('input');
      input!.value = '';

      this.clearXButtonFromNgSelect(idNgSelect);
    }
    else {
      console.warn(`No ngselect found by id ${idNgSelect}`);
    }

  }

  /**
 * Elimina el boton de clear del NgSelect.
 * @param idNgSelect ID del elemento ng-select
 * @returns
 */
  clearXButtonFromNgSelect(idNgSelect: string) {
    if (idNgSelect == null) return;

    let ngSelectElement = document.getElementById(idNgSelect);

    if (ngSelectElement) {
      let clearBtn = ngSelectElement.querySelector('.ng-clear-wrapper');

      if (clearBtn != null) clearBtn.remove();
    }
    else {
      console.warn(`No ngselect found by id ${idNgSelect}`);
    }

  }


  /**
   * Cambia el texto del input del NgSelect.
   * @param idNgSelect ID del elemento ng-select
   * @returns
   */
  setSearchTextFromNgSelect(idNgSelect: string, text: string) {
    if (idNgSelect == null) return;

    let ngSelectElement = document.getElementById(idNgSelect);

    if (ngSelectElement) {
      let input = ngSelectElement.querySelector('input');
      input!.value = text;
    }
    else {
      console.warn(`No ngselect found by id ${idNgSelect}`);
    }

  }


}
