import { Controller } from "@hotwired/stimulus"

// Adds a small "Insert code" helper for Trix editors.
// When a Trix editor is focused, a floating button appears allowing authors
// to insert a fenced code block (<pre><code class="language-...">) into the editor.

export default class extends Controller {
  connect() {
    this.button = document.createElement('button')
    this.button.type = 'button'
    this.button.className = 'trix-code-helper inline-flex items-center px-2 py-1 text-xs rounded bg-slate-100 border text-slate-700'
    this.button.textContent = 'Insert code'
    this.button.style.position = 'absolute'
    this.button.style.zIndex = 1000
    this.button.style.display = 'none'
    document.body.appendChild(this.button)

    this.focusedEditor = null
    this.onFocusIn = this.onFocusIn.bind(this)
    this.onFocusOut = this.onFocusOut.bind(this)
    this.onClick = this.onClick.bind(this)

    document.addEventListener('focusin', this.onFocusIn)
    document.addEventListener('focusout', this.onFocusOut)
    this.button.addEventListener('click', this.onClick)
  }

  disconnect() {
    document.removeEventListener('focusin', this.onFocusIn)
    document.removeEventListener('focusout', this.onFocusOut)
    this.button.removeEventListener('click', this.onClick)
    if (this.button && this.button.parentNode) this.button.parentNode.removeChild(this.button)
  }

  onFocusIn(event) {
    const el = event.target
    // Detect Trix editor element
    if (el && (el.tagName === 'TRIX-EDITOR' || el.closest && el.closest('trix-editor'))) {
      this.focusedEditor = el.tagName === 'TRIX-EDITOR' ? el : el.closest('trix-editor')
      this.showButtonFor(this.focusedEditor)
    }
  }

  onFocusOut(event) {
    // small delay to allow click on button
    setTimeout(() => {
      const active = document.activeElement
      if (!active || !(active.tagName === 'TRIX-EDITOR' || active.closest && active.closest('trix-editor'))) {
        this.hideButton()
        this.focusedEditor = null
      }
    }, 150)
  }

  showButtonFor(editorEl) {
    const rect = editorEl.getBoundingClientRect()
    // position top-right of the editor
    this.button.style.left = (window.scrollX + rect.right - this.button.offsetWidth - 8) + 'px'
    this.button.style.top = (window.scrollY + rect.top + 8) + 'px'
    this.button.style.display = 'inline-block'
  }

  hideButton() {
    this.button.style.display = 'none'
  }

  onClick() {
    if (!this.focusedEditor) return
    const editor = this.focusedEditor.editor
    if (!editor) return

    const lang = window.prompt('Enter language (e.g. ruby, javascript, css, bash):', 'ruby') || 'none'
    const codeHtml = `<pre><code class="language-${this.escapeAttr(lang)}">Your code here</code></pre>`

    // Insert the code block at current cursor position
    try {
      editor.insertHTML(codeHtml)
    } catch (e) {
      // fallback: append at end
      editor.insertHTML('\n' + codeHtml)
    }
  }

  escapeAttr(s) {
    return String(s).replace(/[^a-z0-9_-]/gi, '')
  }
}
