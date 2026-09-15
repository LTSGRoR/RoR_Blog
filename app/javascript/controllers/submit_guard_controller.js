import { Controller } from "@hotwired/stimulus"

// Disables the form's submit buttons while the form is submitting so fast
// double-clicks (or Enter spam) can't create duplicate records. Non-Turbo
// forms (`local: true`) get no auto-disabling from Turbo, so this guards the
// authoring forms. Re-enables on `pageshow` so back navigation keeps working.
export default class extends Controller {
  connect() {
    this._submitting = false

    this._submitHandler = (event) => {
      if (this._submitting) {
        event.preventDefault()
        return
      }
      this._submitting = true
      this.#setDisabled(true)
    }

    this._pageshowHandler = () => {
      this._submitting = false
      this.#setDisabled(false)
    }

    this.element.addEventListener("submit", this._submitHandler, true)
    window.addEventListener("pageshow", this._pageshowHandler)
  }

  disconnect() {
    this.element.removeEventListener("submit", this._submitHandler, true)
    window.removeEventListener("pageshow", this._pageshowHandler)
    this.#setDisabled(false)
  }

  #setDisabled(disabled) {
    this.element
      .querySelectorAll('button[type="submit"], input[type="submit"]')
      .forEach((el) => {
        if (disabled) {
          el.setAttribute("disabled", "")
        } else {
          el.removeAttribute("disabled")
        }
      })
  }
}
