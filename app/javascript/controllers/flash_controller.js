import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { timeout: Number }
  static targets = ["message"]

  connect() {
    this.messageTargets.forEach((el, idx) => {
      this.#animateIn(el, idx * 80)
      this.#scheduleAutoDismiss(el, idx)
    })
  }

  // Called by Stimulus whenever a new [data-flash-target="message"] is inserted
  // into the DOM (e.g. via Turbo Stream), even after initial connect()
  messageTargetConnected(el) {
    this.#animateIn(el)
    this.#scheduleAutoDismiss(el)
  }

  close(event) {
    const message = event.currentTarget.closest('[data-flash-target="message"]')
    if (message) this.dismiss(message)
  }

  dismiss(el) {
    el.classList.remove('translate-x-0', 'opacity-100')
    el.classList.add('translate-x-full', 'opacity-0')
    setTimeout(() => { if (el?.remove) el.remove() }, 300)
  }

  #animateIn(el, delayMs = 0) {
    requestAnimationFrame(() => {
      setTimeout(() => {
        el.classList.remove('translate-x-full', 'opacity-0')
        el.classList.add('translate-x-0', 'opacity-100')
      }, delayMs)
    })
  }

  #scheduleAutoDismiss(el, idx = 0) {
    const t = this.hasTimeoutValue ? this.timeoutValue : 5000
    setTimeout(() => this.dismiss(el), t + idx * 200)
  }
}
