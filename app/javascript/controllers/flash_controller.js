import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { timeout: Number }
  static targets = ["message"]

  connect() {
    const t = this.hasTimeoutValue ? this.timeoutValue : 5000
    if (!this.hasMessageTarget) return

    this.messageTargets.forEach((el, idx) => {
      // stagger slightly if multiple messages
      const delay = t + idx * 200
      setTimeout(() => this.dismiss(el), delay)
    })
  }

  dismiss(el) {
    el.classList.add('transition-opacity', 'duration-300')
    el.style.opacity = '0'
    setTimeout(() => {
      if (el && el.remove) el.remove()
    }, 300)
  }
}
