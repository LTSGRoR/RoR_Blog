import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["picker", "counts"]
  static values = { delay: { type: Number, default: 1000 } }

  initialize() {
    this.hoverTimeout = null
    this.isOpen = false
  }

  disconnect() {
    this.cancelHoverTimer()
  }

  // Show emoji picker after hover delay
  showPicker() {
    if (this.isOpen) {
      return
    }

    this.startHoverTimer(() => {
      if (this.hasPickerTarget) {
        this.pickerTarget.classList.remove("hidden")
        this.isOpen = true
      }
    })
  }

  // Hide emoji picker when mouse leaves
  hidePicker() {
    if (!this.isOpen) {
      this.cancelHoverTimer()
    }
  }

  closePicker() {
    this.cancelHoverTimer()

    if (this.hasPickerTarget) {
      this.pickerTarget.classList.add("hidden")
    }

    this.isOpen = false
  }

  closeOnOutsideClick(event) {
    if (!this.isOpen) {
      return
    }

    if (!this.element.contains(event.target)) {
      this.closePicker()
    }
  }

  // Start hover timer with callback
  startHoverTimer(callback) {
    this.cancelHoverTimer()
    this.hoverTimeout = setTimeout(callback, this.delayValue)
  }

  // Cancel hover timer
  cancelHoverTimer() {
    if (this.hoverTimeout) {
      clearTimeout(this.hoverTimeout)
      this.hoverTimeout = null
    }
  }

  // Toggle expanded reaction counts
  toggleCounts(event) {
    event.preventDefault()
    if (this.hasCountsTarget) {
      this.countsTarget.classList.toggle("hidden")
      event.target.textContent = this.countsTarget.classList.contains("hidden") ? "show all" : "hide"
    }
  }
}
