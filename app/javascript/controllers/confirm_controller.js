import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

export default class extends Controller {
  static targets = ["container"]

  connect() {
    this._previousConfirm = Turbo.config.forms.confirm
    this._confirm = (message) => this.show(message)
    Turbo.config.forms.confirm = this._confirm
    this._request = (event) => {
      event.preventDefault()
      this.show(event.detail.message).then(event.detail.resolve)
    }
    this._beforeCache = () => this._finish?.(false)
    document.addEventListener('app:confirm', this._request)
    document.addEventListener('turbo:before-cache', this._beforeCache)
  }

  disconnect() {
    this._finish?.(false)
    if (Turbo.config.forms.confirm === this._confirm) Turbo.config.forms.confirm = this._previousConfirm
    document.removeEventListener('app:confirm', this._request)
    document.removeEventListener('turbo:before-cache', this._beforeCache)
  }

  show(message) {
    if (this._finish) return Promise.resolve(false)
    return new Promise(resolve => {
      const previousFocus = document.activeElement
      const previousOverflow = document.body.style.overflow
      const dialog = document.createElement('dialog')
      dialog.className = 'm-auto w-[calc(100%-2rem)] max-w-md overflow-hidden rounded-2xl border border-slate-200 bg-white p-0 text-slate-900 shadow-2xl backdrop:bg-slate-950/60 backdrop:backdrop-blur-sm'
      dialog.setAttribute('aria-labelledby', 'confirm-dialog-title')
      dialog.setAttribute('aria-describedby', 'confirm-dialog-message')
      dialog.innerHTML = `
        <div class="border-t-4 border-[#9e0000] px-6 pt-6 pb-5">
          <div class="mb-4 flex h-11 w-11 items-center justify-center rounded-xl bg-red-50 text-[#9e0000]">
            <svg class="h-6 w-6" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.75" aria-hidden="true"><path stroke-linecap="round" stroke-linejoin="round" d="M12 8v5m0 3h.01M10.3 4.9 3.5 17a2 2 0 0 0 1.7 3h13.6a2 2 0 0 0 1.7-3L13.7 4.9a2 2 0 0 0-3.4 0Z"/></svg>
          </div>
          <h2 id="confirm-dialog-title" class="text-lg font-semibold"></h2>
          <p id="confirm-dialog-message" class="mt-2 whitespace-pre-wrap break-words text-sm leading-6 text-slate-600"></p>
        </div>
        <div class="flex flex-wrap justify-end gap-3 border-t border-slate-100 bg-slate-50 px-6 py-4">
          <button type="button" data-confirm-action="cancel" class="min-h-11 rounded-xl border border-slate-200 bg-white px-4 text-sm font-medium text-slate-700 shadow-sm hover:bg-slate-100 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#9e0000] focus-visible:ring-offset-2"></button>
          <button type="button" data-confirm-action="ok" class="min-h-11 rounded-xl bg-[#9e0000] px-4 text-sm font-semibold text-white shadow-sm hover:bg-[#820000] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#9e0000] focus-visible:ring-offset-2"></button>
        </div>`
      dialog.querySelector('#confirm-dialog-title').textContent = this.element.dataset.confirmTitle
      dialog.querySelector('#confirm-dialog-message').textContent = message
      const cancel = dialog.querySelector('[data-confirm-action="cancel"]')
      const ok = dialog.querySelector('[data-confirm-action="ok"]')
      cancel.textContent = this.element.dataset.confirmCancel
      ok.textContent = this.element.dataset.confirmOk
      this._finish = (accepted) => {
        this._finish = null
        dialog.close()
        dialog.remove()
        document.body.style.overflow = previousOverflow
        if (previousFocus?.isConnected) previousFocus.focus()
        resolve(accepted)
      }
      cancel.addEventListener('click', () => this._finish?.(false))
      ok.addEventListener('click', () => this._finish?.(true))
      dialog.addEventListener('cancel', (event) => {
        event.preventDefault()
        this._finish?.(false)
      })
      // Let the native dialog contain focus; keep the underlying chat modal
      // and page Escape handlers from handling this dialog's key events.
      dialog.addEventListener('keydown', (event) => event.stopPropagation())
      dialog.addEventListener('click', (event) => {
        if (event.target !== dialog) return
        const box = dialog.getBoundingClientRect()
        if (event.clientX < box.left || event.clientX > box.right || event.clientY < box.top || event.clientY > box.bottom) this._finish?.(false)
      })
      this.containerTarget.appendChild(dialog)
      document.body.style.overflow = 'hidden'
      dialog.showModal()
      cancel.focus()
    })
  }
}
