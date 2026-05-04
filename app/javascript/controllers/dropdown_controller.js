import { Controller } from "@hotwired/stimulus"

// Wraps the <details> user dropdown and closes it on Escape or focus-out.
// Usage: data-controller="dropdown" on the <details> element.
export default class extends Controller {
  connect() {
    this._keyHandler = (e) => {
      if (e.key === "Escape" && this.element.open) {
        this.close()
        this.element.querySelector("summary")?.focus()
      }
    }

    this._focusOutHandler = (e) => {
      if (!this.element.contains(e.relatedTarget)) {
        this.close()
      }
    }

    document.addEventListener("keydown", this._keyHandler)
    this.element.addEventListener("focusout", this._focusOutHandler)
  }

  disconnect() {
    document.removeEventListener("keydown", this._keyHandler)
    this.element.removeEventListener("focusout", this._focusOutHandler)
  }

  close() {
    this.element.removeAttribute("open")
  }
}
