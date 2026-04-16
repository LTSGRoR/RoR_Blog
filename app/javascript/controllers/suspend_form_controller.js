import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["suspendModal", "suspendForm", "suspendInput", "suspendTimeZone", "suspendTimeZoneLabel", "suspendUserLabel", "banModal", "banForm", "banUserLabel"]

  openSuspend(event) {
    const { url, user } = event.params

    this.suspendFormTarget.action = url
    this.suspendUserLabelTarget.textContent = user
    this.suspendInputTarget.value = ""
    this.suspendInputTarget.min = this.currentLocalDateTime()
    if (this.hasSuspendTimeZoneTarget) {
      const tz = Intl.DateTimeFormat().resolvedOptions().timeZone || "UTC"
      this.suspendTimeZoneTarget.value = tz
      if (this.hasSuspendTimeZoneLabelTarget) {
        this.suspendTimeZoneLabelTarget.textContent = `Time zone: ${tz}`
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
  }

  showModal(target) {
    this.close()
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
