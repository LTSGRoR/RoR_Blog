import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["container"]

  connect() {
    this.container = this.hasContainerTarget ? this.containerTarget : document.body
    window.showCustomConfirm = (message, title = "") => this.show(message, title)

    // Delegate clicks for elements using `data-confirm` or `data-turbo-confirm` attributes
    this._clickHandler = (e) => {
      const el = e.target.closest && e.target.closest('[data-confirm],[data-turbo-confirm]')
      if (!el) return
      e.preventDefault()
      const message = el.getAttribute('data-confirm') || el.getAttribute('data-turbo-confirm') || ''
      this.show(message).then((ok) => {
        if (!ok) return
        // proceed with original action
        if (el.tagName === 'A' && el.href) {
          window.location.href = el.href
          return
        }
        const form = el.closest && el.closest('form')
        if (form) {
          // remove data-confirm to avoid re-interception, then submit
          el.removeAttribute('data-confirm')
          form.submit()
          return
        }
        // fallback: remove attribute and re-dispatch click
        el.removeAttribute('data-confirm')
        el.click()
      })
    }

    document.addEventListener('click', this._clickHandler, true)
  }

  disconnect() {
    document.removeEventListener('click', this._clickHandler, true)
  }

  show(message = '', title = '') {
    return new Promise((resolve) => {
      const overlay = document.createElement('div')
      overlay.setAttribute('role', 'dialog')
      overlay.setAttribute('aria-modal', 'true')
      overlay.className = 'fixed inset-0 z-50 flex items-center justify-center bg-slate-900/50 p-4'

      const dialog = document.createElement('div')
      dialog.className = 'w-full max-w-md rounded-2xl border border-slate-200 bg-white p-6 shadow-lg transform transition-all duration-150 scale-95 opacity-0'
      dialog.innerHTML = `
        <div class="flex flex-col items-center text-center gap-4">
          <div class="flex items-center gap-3">
            <svg class="h-8 w-8 text-red-600" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
              <path fill-rule="evenodd" d="M8.257 3.099c.765-1.36 2.721-1.36 3.486 0l5.454 9.691c.75 1.333-.213 2.99-1.742 2.99H4.545c-1.529 0-2.492-1.657-1.742-2.99L8.257 3.1zM9 7a1 1 0 112 0v3a1 1 0 11-2 0V7zm1 7a1.25 1.25 0 100-2.5A1.25 1.25 0 0010 14z" clip-rule="evenodd" />
            </svg>
            <h3 class="text-lg font-semibold text-slate-900">${this._escapeHtml(title || 'Are you sure?')}</h3>
          </div>

          <div class="mt-4 flex items-center justify-center gap-3">
            <button data-confirm-action="cancel" class="rounded-lg border border-slate-300 px-4 py-2 text-sm font-medium text-slate-600 hover:bg-slate-50">${this._escapeHtml(i18nOkCancel('cancel') || 'Cancel')}</button>
            <button data-confirm-action="ok" class="rounded-lg bg-red-600 px-4 py-2 text-sm font-semibold text-white hover:bg-red-700">${this._escapeHtml(i18nOkCancel('ok') || 'OK')}</button>
          </div>
        </div>
      `

      overlay.appendChild(dialog)

      const cleanup = () => {
        overlay.remove()
        document.removeEventListener('keydown', onKey)
        document.body.classList.remove('overflow-hidden')
      }

      const onOk = () => { cleanup(); resolve(true) }
      const onCancel = () => { cleanup(); resolve(false) }

      dialog.querySelector('[data-confirm-action="ok"]').addEventListener('click', onOk)
      dialog.querySelector('[data-confirm-action="cancel"]').addEventListener('click', onCancel)
      const closeBtn = dialog.querySelector('[data-confirm-action="close"]')
      if (closeBtn) closeBtn.addEventListener('click', onCancel)

      const onKey = (e) => {
        if (e.key === 'Escape') onCancel()
        if (e.key === 'Enter') onOk()
      }

      document.addEventListener('keydown', onKey)

      this.container.appendChild(overlay)
      document.body.classList.add('overflow-hidden')

      // trigger enter animation
      requestAnimationFrame(() => {
        dialog.classList.remove('scale-95', 'opacity-0')
        dialog.classList.add('scale-100', 'opacity-100')
      })

      // focus OK button
      dialog.querySelector('[data-confirm-action="ok"]').focus()
    })
  }

  _escapeHtml(str) {
    if (!str) return ''
    return String(str)
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#39;')
  }
}

function i18nOkCancel(key) {
  // Simple client-side fallback; replace with i18n if available
  const map = { ok: 'OK', cancel: 'Cancel' }
  return map[key]
}
