import { Controller } from "@hotwired/stimulus"

// Keeps a flyout panel open while the mouse travels between trigger and panel.
// A short delay prevents the panel closing in the "dead zone" gap between them.
export default class extends Controller {
  static targets = ["panel"]

  #timer = null
  #resizeHandler = () => {
    if (!this.panelTarget.classList.contains("hidden")) {
      this.positionPanel()
    }
  }

  connect() {
    window.addEventListener("resize", this.#resizeHandler)
  }

  disconnect() {
    window.removeEventListener("resize", this.#resizeHandler)
  }

  show() {
    clearTimeout(this.#timer)
    this.panelTarget.classList.remove("hidden")
    this.positionPanel()
  }

  toggle(event) {
    event.preventDefault()
    clearTimeout(this.#timer)
    const isHidden = this.panelTarget.classList.toggle("hidden")
    if (!isHidden) {
      this.positionPanel()
    }
  }

  hide() {
    this.#timer = setTimeout(() => {
      this.panelTarget.classList.add("hidden")
    }, 100)
  }

  stayOpen() {
    clearTimeout(this.#timer)
  }

  positionPanel() {
    const panel = this.panelTarget
    const triggerRect = this.element.getBoundingClientRect()
    const panelWidth = panel.getBoundingClientRect().width || 112
    const gap = 8
    const availableRight = window.innerWidth - triggerRect.right - gap

    if (availableRight >= panelWidth) {
      panel.style.left = "100%"
      panel.style.right = "auto"
      panel.style.marginLeft = "0.25rem"
      panel.style.marginRight = "0"
    } else {
      panel.style.left = "auto"
      panel.style.right = "100%"
      panel.style.marginLeft = "0"
      panel.style.marginRight = "0.25rem"
    }

    panel.style.top = "0"
  }
}
