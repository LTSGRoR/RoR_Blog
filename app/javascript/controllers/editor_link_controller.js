import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["editor", "dialog", "text", "url", "error", "save", "remove", "notice"]
  static values = { insert: String, update: String, invalid: String, label: String, selection: String }

  connect() {
    this.connected = true
    this.intercept = event => {
      if (!event.target.closest('[data-trix-action="link"]')) return
      event.preventDefault()
      event.stopImmediatePropagation()
      if (event.type === "click") this.open()
    }
    this.shortcut = event => {
      if ((event.metaKey || event.ctrlKey) && event.key.toLowerCase() === "k") {
        event.preventDefault()
        event.stopImmediatePropagation()
        this.open()
      }
    }
    this.initialize = () => this.setupToolbar()
    this.editorTarget.addEventListener("trix-initialize", this.initialize)
    this.editorTarget.addEventListener("keydown", this.shortcut, true)
    if (this.editorTarget.editor) this.setupToolbar()
  }

  setupToolbar() {
    if (this.toolbar) return
    this.toolbar = this.editorTarget.toolbarElement
    for (const event of ["pointerdown", "mousedown", "click"]) this.toolbar.addEventListener(event, this.intercept, true)
    const button = this.toolbar.querySelector('[data-trix-action="link"]')
    button.setAttribute("aria-label", this.labelValue)
    button.tabIndex = 0
  }

  disconnect() {
    this.connected = false
    this.editorTarget.removeEventListener("trix-initialize", this.initialize)
    this.editorTarget.removeEventListener("keydown", this.shortcut, true)
    if (this.toolbar) {
      for (const event of ["pointerdown", "mousedown", "click"]) this.toolbar.removeEventListener(event, this.intercept, true)
    }
    if (this.dialogTarget.open) this.dialogTarget.close()
    this.toolbar = null
  }

  open() {
    if (this.dialogTarget.open) return
    const editor = this.editorTarget.editor
    // Keyboard shortcuts follow the toolbar's availability (for example,
    // Trix does not support text links on selected image attachments).
    if (!editor.canActivateAttribute("href")) return
    const doc = editor.getDocument()
    this.range = editor.getSelectedRange().slice()
    const href = doc.getCommonAttributesAtRange(this.range).href
    if (href && this.range[0] === this.range[1]) {
      this.range = doc.getRangeOfCommonAttributeAtPosition("href", this.range[0])
    }
    // A sliced Trix document adds its own trailing paragraph break. Slice
    // the full text instead so the dialog reflects the actual selection.
    this.originalText = doc.toString().slice(this.range[0], this.range[1])
    this.preserveContent = /[\n\uFFFC]/.test(this.originalText)
    this.textTarget.value = this.preserveContent ? this.selectionValue : this.originalText
    this.textTarget.readOnly = this.preserveContent
    this.noticeTarget.hidden = !this.preserveContent
    this.urlTarget.value = href || ""
    this.removeTarget.hidden = !href
    this.saveTarget.textContent = href ? this.updateValue : this.insertValue
    this.errorTarget.hidden = true
    this.urlTarget.removeAttribute("aria-invalid")
    this.dialogTarget.showModal()
    this.urlTarget.focus()
  }

  save(event) {
    if (event.type === "keydown" && event.target.tagName === "BUTTON") return
    event.preventDefault()
    let url = this.urlTarget.value.trim()
    if (url && !/^[a-z][a-z\d+.-]*:/i.test(url)) url = `https://${url}`
    try {
      const parsed = new URL(url)
      if (!["https:", "http:", "mailto:", "tel:"].includes(parsed.protocol) ||
          (["mailto:", "tel:"].includes(parsed.protocol) && !parsed.pathname)) throw new Error("Invalid link")
    } catch {
      this.errorTarget.textContent = this.invalidValue
      this.errorTarget.hidden = false
      this.urlTarget.setAttribute("aria-invalid", "true")
      this.urlTarget.focus()
      return
    }
    const editor = this.editorTarget.editor
    const text = this.preserveContent ? this.originalText :
      (this.textTarget.value.trim() ? this.textTarget.value : (this.originalText || url))
    editor.recordUndoEntry("Edit link")
    editor.setSelectedRange(this.range)
    if (text !== this.originalText) {
      editor.insertString(text)
      this.range = [this.range[0], this.range[0] + text.length]
      editor.setSelectedRange(this.range)
    }
    editor.activateAttribute("href", url)
    this.close()
  }

  remove(event) {
    event.preventDefault()
    const editor = this.editorTarget.editor
    editor.recordUndoEntry("Remove link")
    editor.setSelectedRange(this.range)
    editor.deactivateAttribute("href")
    this.close()
  }

  close() {
    this.dialogTarget.close()
    this.restoreSelection()
  }

  cancel(event) {
    event.preventDefault()
    this.close()
  }

  restoreSelection() {
    if (!this.connected) return
    this.editorTarget.focus({ preventScroll: true })
    if (this.range) this.editorTarget.editor.setSelectedRange(this.range)
  }
}
