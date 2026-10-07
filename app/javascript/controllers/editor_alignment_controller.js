import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["editor"]
  static values = { left: String, center: String, right: String, label: String }

  connect() {
    this.initialize = () => this.setup()
    this.change = () => this.update()
    this.intercept = event => {
      const button = event.target.closest("[data-editor-align]")
      if (!button) return
      event.preventDefault()
      event.stopImmediatePropagation()
      if (event.type === "click") this.align(button.dataset.editorAlign)
    }
    this.editorTarget.addEventListener("trix-initialize", this.initialize)
    this.editorTarget.addEventListener("trix-selection-change", this.change)
    this.editorTarget.addEventListener("trix-change", this.change)
    if (this.editorTarget.editor) this.setup()
  }

  setup() {
    if (this.group) return
    this.toolbar = this.editorTarget.toolbarElement
    this.group = document.createElement("span")
    this.group.className = "trix-button-group editor-alignment-buttons"
    this.group.setAttribute("role", "group")
    this.group.setAttribute("aria-label", this.labelValue)
    for (const direction of ["left", "center", "right"]) {
      const button = document.createElement("button")
      button.type = "button"
      button.className = "trix-button editor-alignment-button"
      button.dataset.editorAlign = direction
      button.title = this[`${direction}Value`]
      button.setAttribute("aria-label", this[`${direction}Value`])
      const shortStart = { left: 3, center: 6, right: 9 }[direction]
      button.innerHTML = `<svg aria-hidden="true" viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" stroke-width="2"><path d="M3 5h18M${shortStart} 10h12M3 15h18M${shortStart} 20h12"/></svg>`
      this.group.append(button)
    }
    const row = this.toolbar.querySelector(".trix-button-row")
    row.insertBefore(this.group, row.querySelector(".trix-button-group--file-tools"))
    for (const event of ["pointerdown", "mousedown", "click"]) this.toolbar.addEventListener(event, this.intercept, true)
    this.update()
  }

  disconnect() {
    this.editorTarget.removeEventListener("trix-initialize", this.initialize)
    this.editorTarget.removeEventListener("trix-selection-change", this.change)
    this.editorTarget.removeEventListener("trix-change", this.change)
    if (this.toolbar) {
      for (const event of ["pointerdown", "mousedown", "click"]) this.toolbar.removeEventListener(event, this.intercept, true)
    }
    this.group?.remove()
    this.group = null
    this.toolbar = null
  }

  selectedBlocks() {
    const editor = this.editorTarget.editor
    const doc = editor.getDocument()
    const [start, end] = editor.getSelectedRange()
    const first = doc.locationFromPosition(start).index
    const last = doc.locationFromPosition(Math.max(start, end - 1)).index
    return Array.from({ length: last - first + 1 }, (_, i) => {
      const position = doc.positionFromLocation({ index: first + i, offset: 0 })
      return { position, block: doc.getBlockAtPosition(position) }
    })
  }

  align(direction) {
    if (!["left", "center", "right"].includes(direction)) return
    const editor = this.editorTarget.editor
    const range = editor.getSelectedRange().slice()
    const blocks = this.selectedBlocks()
    editor.recordUndoEntry("Align text")
    for (const { position, block } of blocks) {
      if (!block.getAttributes().length) {
        editor.setSelectedRange([position, position])
        editor.activateAttribute("alignment")
      }
      const classes = (block.htmlAttributes.class || "").split(/\s+/)
        .filter(name => name && !/^rt-align-(left|center|right)$/.test(name))
      classes.push(`rt-align-${direction}`)
      // Trix's public method uses this spelling (Atribute with one t).
      editor.setHTMLAtributeAtPosition(position, "class", classes.join(" "))
    }
    this.editorTarget.focus({ preventScroll: true })
    editor.setSelectedRange(range)
    this.update()
  }

  update() {
    if (!this.group) return
    const directions = this.selectedBlocks().map(({ block }) =>
      (block.htmlAttributes.class || "").match(/\brt-align-(left|center|right)\b/)?.[1] || "left")
    for (const button of this.group.querySelectorAll("button")) {
      const active = directions.every(direction => direction === button.dataset.editorAlign)
      button.classList.toggle("trix-active", active)
      button.setAttribute("aria-pressed", String(active))
    }
  }
}
