import { Controller } from "@hotwired/stimulus"
import { normalizeTimeZone } from "controllers/time_zone_aliases"

export default class extends Controller {
  static targets = ["suspendModal", "suspendForm", "suspendInput", "suspendTimeZone", "suspendTimeZoneLabel", "suspendUserLabel", "banModal", "banForm", "banUserLabel"]
  connect() {
    this._submitEndHandler = this.handleSubmitEnd.bind(this)
    document.addEventListener("turbo:submit-end", this._submitEndHandler)

    this._trapHandler = (e) => {
      if (e.key !== "Tab") return
      const modal = this.#openModal()
      if (!modal) return
      const focusables = Array.from(
        modal.querySelectorAll('a[href], button:not([disabled]), input:not([disabled]), [tabindex]:not([tabindex="-1"])')
      )
      if (!focusables.length) return

      const first = focusables[0]
      const last = focusables[focusables.length - 1]
      const active = document.activeElement
      const inside = modal.contains(active)

      if (e.shiftKey && (active === first || !inside)) {
        e.preventDefault()
        last.focus()
      } else if (!e.shiftKey && (active === last || !inside)) {
        e.preventDefault()
        first.focus()
      }
    }
    document.addEventListener("keydown", this._trapHandler)
  }

  disconnect() {
    document.removeEventListener("turbo:submit-end", this._submitEndHandler)
    document.removeEventListener("keydown", this._trapHandler)
    document.body.classList.remove("overflow-hidden")
  }

  #openModal() {
    if (this.hasSuspendModalTarget && !this.suspendModalTarget.classList.contains("hidden")) {
      return this.suspendModalTarget
    }
    if (this.hasBanModalTarget && !this.banModalTarget.classList.contains("hidden")) {
      return this.banModalTarget
    }
    return null
  }

  handleSubmitEnd(event) {
    if (!event.detail.success) return
    const form = event.detail.formSubmission.formElement
    if (
      (this.hasSuspendFormTarget && form === this.suspendFormTarget) ||
      (this.hasBanFormTarget && form === this.banFormTarget)
    ) {
      this.close()
    }
  }
  openSuspend(event) {
    const { url, user } = event.params

    this.suspendFormTarget.action = url
    this.suspendUserLabelTarget.textContent = user
    this.suspendInputTarget.value = ""
    this.suspendInputTarget.min = this.currentLocalDateTime()
    if (this.hasSuspendTimeZoneTarget) {
      const tz = normalizeTimeZone(Intl.DateTimeFormat().resolvedOptions().timeZone || "UTC")

      this.suspendTimeZoneTarget.value = tz
      if (this.hasSuspendTimeZoneLabelTarget) {
        this.suspendTimeZoneLabelTarget.textContent = tz
      }
    }
    this.showModal(this.suspendModalTarget)

    this.suspendInputTarget.focus()
  }

  openBan(event) {
    const { url, user } = event.params

    this.banFormTarget.action = url
    this.banUserLabelTarget.textContent = user
    this.showModal(this.banModalTarget)
    // Land focus inside the dialog, on the safe Cancel control.
    this.banModalTarget.querySelector("button")?.focus()
  }

  showModal(target) {
    this.close()
    this._previouslyFocused = document.activeElement
    target.classList.remove("hidden")
    target.classList.add("flex")
    document.body.classList.add("overflow-hidden")
  }

  close() {
    if (this.hasSuspendModalTarget) {
      this.suspendModalTarget.classList.add("hidden")
      this.suspendModalTarget.classList.remove("flex")
    }

    if (this.hasBanModalTarget) {
      this.banModalTarget.classList.add("hidden")
      this.banModalTarget.classList.remove("flex")
    }

    document.body.classList.remove("overflow-hidden")

    if (this._previouslyFocused && this._previouslyFocused.isConnected) {
      this._previouslyFocused.focus()
    }
    this._previouslyFocused = null
  }

  backdropCloseSuspend(event) {
    if (event.target === this.suspendModalTarget) {
      this.close()
    }
  }

  backdropCloseBan(event) {
    if (event.target === this.banModalTarget) {
      this.close()
    }
  }

  currentLocalDateTime() {
    const now = new Date()
    now.setMinutes(now.getMinutes() - now.getTimezoneOffset())

    return now.toISOString().slice(0, 16)
  }
}
