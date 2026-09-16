import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["modal"]

  connect() {
    this._trapHandler = (e) => {
      if (e.key !== "Tab") return
      const modal = this.#openModal()
      if (!modal) return
      this.#trap(e, modal)
    }
    this.closeAll()
  }

  open(event) {
    const modalId = event.params.id
    this.closeAll()

    const modal = this.modalTargets.find((element) => element.dataset.modalId === modalId)
    if (!modal) return

    this._previouslyFocused = document.activeElement
    modal.classList.remove("hidden")
    modal.classList.add("flex")
    document.body.classList.add("overflow-hidden")
    document.addEventListener("keydown", this._trapHandler)
    this.#focusables(modal)[0]?.focus()
  }

  close(event) {
    if (event) event.preventDefault()

    this.closeAll()
    document.body.classList.remove("overflow-hidden")
    document.removeEventListener("keydown", this._trapHandler)
    if (this._previouslyFocused && this._previouslyFocused.isConnected) this._previouslyFocused.focus()
    this._previouslyFocused = null
  }

  backdropClose(event) {
    if (event.target === event.currentTarget) this.close(event)
  }

  closeOnEscape(event) {
    if (event.key === "Escape") this.close(event)
  }

  closeAll() {
    this.modalTargets.forEach((modal) => {
      modal.classList.add("hidden")
      modal.classList.remove("flex")
    })
  }

  #openModal() {
    return this.modalTargets.find((modal) => !modal.classList.contains("hidden"))
  }

  #focusables(modal) {
    return Array.from(
      modal.querySelectorAll('a[href], button:not([disabled]), input:not([disabled]), textarea, select, [tabindex]:not([tabindex="-1"])')
    )
  }

  #trap(event, modal) {
    const focusables = this.#focusables(modal)
    if (!focusables.length) return

    const first = focusables[0]
    const last = focusables[focusables.length - 1]
    const active = document.activeElement
    const inside = modal.contains(active)

    if (event.shiftKey && (active === first || !inside)) {
      event.preventDefault()
      last.focus()
    } else if (!event.shiftKey && (active === last || !inside)) {
      event.preventDefault()
      first.focus()
    }
  }
}
