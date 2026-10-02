import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button", "tag"]

  toggle() {
    this.tagTargets.forEach(tag => {
      tag.hidden = false
      tag.style.removeProperty("display")
    })
    this.buttonTarget.setAttribute("aria-expanded", "true")
    this.buttonTarget.hidden = true
    this.buttonTarget.style.display = "none"
  }
}
