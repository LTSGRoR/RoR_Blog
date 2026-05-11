import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["modal"]

  connect() {
    this.closeAll()
  }

  open(event) {
    const modalId = event.params.id
    this.closeAll()

    const modal = this.modalTargets.find((element) => element.dataset.modalId === modalId)
    if (!modal) return

    modal.classList.remove("hidden")
    modal.classList.add("flex")
    document.body.classList.add("overflow-hidden")
  }

  close(event) {
    if (event) event.preventDefault()

    this.closeAll()
    document.body.classList.remove("overflow-hidden")
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
}
