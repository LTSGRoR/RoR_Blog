import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["suspendModal", "suspendForm", "suspendInput", "suspendTimeZone", "suspendTimeZoneLabel", "suspendUserLabel", "banModal", "banForm", "banUserLabel"]
  connect() {
    this._submitEndHandler = this.handleSubmitEnd.bind(this)
    document.addEventListener("turbo:submit-end", this._submitEndHandler)
  }

  disconnect() {
    document.removeEventListener("turbo:submit-end", this._submitEndHandler)
    document.body.classList.remove("overflow-hidden")
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
      let tz = Intl.DateTimeFormat().resolvedOptions().timeZone || "UTC"
      // map a few common legacy/browser aliases to canonical IANA names
      const aliasMap = {
        "Asia/Saigon": "Asia/Ho_Chi_Minh",
      }
      if (aliasMap[tz]) tz = aliasMap[tz]

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
