import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "preview", "placeholder", "removeField"]

  change(event) {
    const file = event.target.files[0]
    if (!file) return

    const reader = new FileReader()
    reader.onload = (e) => {
      this.previewTarget.src = e.target.result
      this.previewTarget.classList.remove("hidden")
      if (this.hasPlaceholderTarget) {
        this.placeholderTarget.classList.add("hidden")
      }
    }
    reader.readAsDataURL(file)
  }

  remove() {
    if (!this.hasInputTarget) return
    this.inputTarget.value = ''
    if (this.hasPreviewTarget) {
      this.previewTarget.src = ''
      this.previewTarget.classList.add('hidden')
    }
    if (this.hasPlaceholderTarget) {
      this.placeholderTarget.classList.remove('hidden')
    }
    if (this.hasRemoveFieldTarget) {
      this.removeFieldTarget.value = '1'
    }
  }
}
