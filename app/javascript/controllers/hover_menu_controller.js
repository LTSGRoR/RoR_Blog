import { Controller } from "@hotwired/stimulus"

// Keeps a flyout panel open while the mouse travels between trigger and panel.
// A short delay prevents the panel closing in the "dead zone" gap between them.
export default class extends Controller {
  static targets = ["panel"]

  #timer = null

  show() {
    clearTimeout(this.#timer)
    this.panelTarget.classList.remove("hidden")
  }

  hide() {
    this.#timer = setTimeout(() => {
      this.panelTarget.classList.add("hidden")
    }, 100)
  }

  stayOpen() {
    clearTimeout(this.#timer)
  }
}
