import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["topBtn", "bottomBtn"]

  connect() {
    this.checkVisibility = this.checkVisibility.bind(this)
    window.addEventListener('scroll', this.checkVisibility, { passive: true })
    window.addEventListener('resize', this.checkVisibility)
    this.checkVisibility()
  }

  disconnect() {
    window.removeEventListener('scroll', this.checkVisibility)
    window.removeEventListener('resize', this.checkVisibility)
  }

  checkVisibility() {
    const docHeight = Math.max(document.body.scrollHeight, document.documentElement.scrollHeight)
    const winHeight = window.innerHeight
    if (docHeight > winHeight + 200) {
      this.show()
    } else {
      this.hide()
    }
  }

  show() {
    this.element.classList.remove('opacity-0', 'pointer-events-none')
  }

  hide() {
    this.element.classList.add('opacity-0', 'pointer-events-none')
  }

  scrollToTop(event) {
    event.preventDefault()
    window.scrollTo({ top: 0, behavior: 'smooth' })
  }

  scrollToBottom(event) {
    event.preventDefault()
    const bottom = Math.max(document.body.scrollHeight, document.documentElement.scrollHeight) - window.innerHeight
    window.scrollTo({ top: bottom, behavior: 'smooth' })
  }
}
