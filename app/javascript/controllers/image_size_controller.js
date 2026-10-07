import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["editor", "controls", "handle"]

  connect() {
    this.observer = new ResizeObserver(() => this.refresh())
    this.observer.observe(this.editorTarget)
    this.onImageLoad = () => this.refresh()
    this.editorTarget.addEventListener("load", this.onImageLoad, true)
  }

  disconnect() {
    this.cancelDrag()
    this.observer.disconnect()
    this.editorTarget.removeEventListener("load", this.onImageLoad, true)
    cancelAnimationFrame(this.frame)
  }

  select(event) {
    if (this.drag) return
    this.showAttachment(event.target.closest("figure[data-trix-id]")?.dataset.trixId)
  }

  selectionChanged() {
    if (this.drag || document.activeElement !== this.editorTarget) return
    const editor = this.editorTarget.editor
    const attachments = editor.getDocument()
      .getDocumentAtRange(editor.getSelectedRange()).getAttachments()
    // Trix collapses its selection while opening the caption editor. Keep
    // the resize handle until the author explicitly clicks another block.
    if (attachments[0]) this.showAttachment(attachments[0].id)
  }

  showAttachment(id) {
    this.attachmentId = Number(id) || null
    this.refresh()
  }

  get attachment() {
    return this.editorTarget.editor?.getDocument().getAttachmentById(this.attachmentId)
  }

  get image() {
    return this.editorTarget.querySelector(`figure[data-trix-id="${this.attachmentId}"] img`)
  }

  refresh() {
    cancelAnimationFrame(this.frame)
    this.frame = requestAnimationFrame(() => this.positionControls())
  }

  positionControls() {
    const image = this.image
    if (!this.attachment || !image) {
      this.controlsTarget.hidden = true
      return
    }
    const rect = image.getBoundingClientRect()
    const wrapper = this.element.getBoundingClientRect()
    this.controlsTarget.hidden = false
    Object.assign(this.controlsTarget.style, {
      left: `${rect.left - wrapper.left + this.element.scrollLeft}px`,
      top: `${rect.top - wrapper.top + this.element.scrollTop}px`,
      width: `${rect.width}px`,
      height: `${rect.height}px`
    })
  }

  startDrag(event) {
    if (event.button !== 0 || this.drag || !this.attachment || !this.image) return
    event.preventDefault()
    const rect = this.image.getBoundingClientRect()
    if (!rect.width || !rect.height) return
    this.drag = {
      pointerId: event.pointerId,
      x: event.clientX,
      y: event.clientY,
      width: rect.width,
      ratio: rect.height / rect.width,
      original: this.attachment.getAttributes(),
      changed: false
    }
    this.handleTarget.focus({ preventScroll: true })
    this.handleTarget.setPointerCapture(event.pointerId)
    this.element.classList.add("image-resizing")
  }

  moveDrag(event) {
    if (!this.drag || this.drag.pointerId !== event.pointerId) return
    if (!this.image || !this.attachment) {
      this.finishDrag()
      return
    }
    event.preventDefault()
    const { x, y, width, ratio } = this.drag
    // Project movement onto the image diagonal to preserve proportions.
    const delta = ((event.clientX - x) + ratio * (event.clientY - y)) / (1 + ratio * ratio)
    const nextWidth = this.clampWidth(width + delta)
    if (!this.drag.changed && nextWidth === Math.round(width)) return
    if (!this.drag.changed) {
      this.editorTarget.editor.recordUndoEntry("Resize image")
      this.drag.changed = true
    }
    this.setDimensions(nextWidth, ratio)
  }

  endDrag(event) {
    if (!this.drag || this.drag.pointerId !== event.pointerId) return
    this.moveDrag(event)
    this.finishDrag()
  }

  cancelDrag(event) {
    if (!this.drag) return
    event?.preventDefault()
    if (this.drag.changed && this.attachment) {
      const { width, height } = this.drag.original
      this.attachment.setAttributes({ width, height })
    }
    this.finishDrag()
  }

  finishDrag() {
    const pointerId = this.drag.pointerId
    this.drag = null
    if (this.handleTarget.hasPointerCapture(pointerId)) this.handleTarget.releasePointerCapture(pointerId)
    this.element.classList.remove("image-resizing")
    this.refresh()
  }

  keyResize(event) {
    if (event.key === "Escape" && this.drag) {
      event.preventDefault()
      this.cancelDrag()
      return
    }
    const direction = { ArrowLeft: -1, ArrowUp: -1, ArrowRight: 1, ArrowDown: 1 }[event.key]
    if (!direction || this.drag || !this.image || !this.attachment) return
    event.preventDefault()
    const rect = this.image.getBoundingClientRect()
    if (!rect.width || !rect.height) return
    this.editorTarget.editor.recordUndoEntry("Resize image")
    this.setDimensions(this.clampWidth(rect.width + direction * (event.shiftKey ? 40 : 10)), rect.height / rect.width)
  }

  clampWidth(width) {
    // Use the containing block's width, rather than space to the image's
    // right: centered and right-aligned images must be able to grow too.
    const container = this.image.closest("figure")?.parentElement || this.editorTarget
    const rect = container.getBoundingClientRect()
    const style = getComputedStyle(container)
    const padding = (parseFloat(style.paddingLeft) || 0) + (parseFloat(style.paddingRight) || 0)
    const max = Math.max(1, Math.floor(rect.width - padding))
    return Math.round(Math.min(max, Math.max(Math.min(48, max), width)))
  }

  setDimensions(width, ratio) {
    this.attachment?.setAttributes({ width, height: Math.max(1, Math.round(width * ratio)) })
    this.refresh()
  }
}
