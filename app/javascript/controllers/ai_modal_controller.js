import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["textarea", "submit", "history", "spinner", "icon"]
  static values = { signedIn: Boolean }

  connect() {
    this.url = null
    this._eventHandler = (e) => this.open(e)
    this._keyHandler = (e) => {
      if (this.element.classList.contains('hidden')) return
      if (e.key === 'Escape') this.close()
      if (e.key === 'Tab') this._trapFocus(e)
    }
    this.element.addEventListener('ai:open', this._eventHandler)
    document.addEventListener('keydown', this._keyHandler)

    if (this.hasTextareaTarget) {
      this.textareaTarget.addEventListener('input', () => {
        this._resize()
        this._updateSubmitState()
      })
      this.textareaTarget.addEventListener('keydown', (e) => {
        if (e.key === 'Enter' && !e.shiftKey) {
          e.preventDefault()
          this.submit(e)
        }
      })
      // initial resize in case of prefilled content
      this._resize()
      this._updateSubmitState()
    }

    if (this.hasHistoryTarget) {
      this._observer = new MutationObserver(() => {
        this._scrollHistoryToBottom()
      })
      this._observer.observe(this.historyTarget, { childList: true, subtree: true })
    }
  }

  disconnect() {
    this.element.removeEventListener('ai:open', this._eventHandler)
    document.removeEventListener('keydown', this._keyHandler)
    if (this._observer) this._observer.disconnect()
    this._clearPendingPoller()
  }

  open(event) {
    const detail = event?.detail || {}
    this.url = detail.url || this.url
    this._previouslyFocused = document.activeElement
    this.element.classList.remove('hidden')
    if (this.signedInValue && this.hasTextareaTarget) {
      this.textareaTarget.removeAttribute('disabled')
      this.textareaTarget.focus()
      this._updateSubmitState()
    } else if (this.hasTextareaTarget) {
      this.textareaTarget.setAttribute('disabled', '')
      this._setSubmitDisabled(true)
    }
    // scroll history to bottom
    if (this.hasHistoryTarget) {
      this._scrollHistoryToBottom()
    }
  }

  close() {
    this.element.classList.add('hidden')
    if (this._previouslyFocused && this._previouslyFocused.isConnected) {
      this._previouslyFocused.focus()
    }
    this._previouslyFocused = null
  }

  async submit(e) {
    e?.preventDefault()
    if (!this.signedInValue) return
    if (!this.url) return

    const content = this.textareaTarget.value.trim()
    if (content.length === 0) return

    if (this.hasSubmitTarget) {
      this.submitTarget.setAttribute('disabled', '')
      this.submitTarget.classList.add('opacity-60', 'pointer-events-none')
      this.submitTarget.setAttribute('aria-disabled', 'true')
      this._showSpinner()
    }
    const token = document.querySelector("meta[name='csrf-token']")?.content

    try {
      const resp = await fetch(this.url, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': token || '',
          'Accept': 'application/json'
        },
        body: JSON.stringify({ message: content })
      })

      if (!resp.ok) throw new Error('Request failed')

      const json = await resp.json()

      // If server returned rendered HTML for immediate feedback, append it
      if (json.html && this.hasHistoryTarget) {
        this.historyTarget.insertAdjacentHTML('beforeend', json.html)
        this._scrollHistoryToBottom()
      }

      // track pending chat id so we can re-enable the send button when job completes
      if (json.id) {
        this.pendingChatId = json.id
        this.pendingStatusUrl = json.status_url || null
        this.pendingSince = Date.now()
        this._startPendingPoller()
      } else {
        // if server didn't return an id, re-enable the button
        if (this.hasSubmitTarget) this._enableSubmit()
      }

      this.textareaTarget.value = ''
      this._resize()
      this._updateSubmitState()
    } catch (err) {
      console.error('[ai-modal] submit failed', err)
      if (this.hasSubmitTarget) this._enableSubmit()
    } finally {
      // Do not blindly re-enable here — we wait for background job to finish.
    }
  }

  _enableSubmit() {
    if (!this.hasSubmitTarget) return
    this.submitTarget.classList.remove('opacity-60', 'pointer-events-none')
    this.submitTarget.removeAttribute('aria-disabled')
    this._hideSpinner()
    this._updateSubmitState()
  }

  _showSpinner() {
    if (this.hasSpinnerTarget) {
      this.spinnerTarget.classList.remove('hidden')
    }
    if (this.hasIconTarget) {
      this.iconTarget.classList.add('hidden')
    }
  }

  _hideSpinner() {
    if (this.hasSpinnerTarget) {
      this.spinnerTarget.classList.add('hidden')
    }
    if (this.hasIconTarget) {
      this.iconTarget.classList.remove('hidden')
    }
  }

  // Keep keyboard focus cycling inside the open dialog. Completion of a
  // pending chat is detected solely by the polled `ready` flag (see
  // _pollPendingStatus) — never by sniffing the rendered text, which breaks
  // under translated placeholders.
  _trapFocus(e) {
    const focusables = Array.from(
      this.element.querySelectorAll('a[href], button:not([disabled]), textarea:not([disabled]), input:not([disabled])')
    )
    if (!focusables.length) return

    const first = focusables[0]
    const last = focusables[focusables.length - 1]
    const active = document.activeElement
    const inside = this.element.contains(active)

    if (e.shiftKey && (active === first || !inside)) {
      e.preventDefault()
      last.focus()
    } else if (!e.shiftKey && (active === last || !inside)) {
      e.preventDefault()
      first.focus()
    }
  }

  _startPendingPoller() {
    this._clearPendingPoller()
    this._pendingPoller = setInterval(() => {
      this._pollPendingStatus()
    }, 1500)
  }

  _clearPendingPoller() {
    if (!this._pendingPoller) return
    clearInterval(this._pendingPoller)
    this._pendingPoller = null
  }

  async _pollPendingStatus() {
    if (!this.pendingChatId || !this.pendingStatusUrl) return

    try {
      const resp = await fetch(this.pendingStatusUrl, {
        method: 'GET',
        headers: { Accept: 'application/json' }
      })
      if (!resp.ok) return

      const json = await resp.json()
      if (json?.html) this._replacePendingItemHtml(json.html)

      if (json?.ready) {
        this._completePending()
        return
      }

      if (this.pendingSince && Date.now() - this.pendingSince > 60000) {
        // Avoid blocking the send action forever if something goes wrong.
        this._completePending()
      }
    } catch (_err) {
      // Silent fallback: Turbo stream may still deliver the update.
    }
  }

  _replacePendingItemHtml(html) {
    const wrapper = document.createElement('div')
    wrapper.innerHTML = html.trim()
    const replacement = wrapper.firstElementChild
    if (!replacement) return

    const existing = document.getElementById(`chat_history_${this.pendingChatId}`)
    if (existing) {
      existing.replaceWith(replacement)
      this._scrollHistoryToBottom()
    }
  }

  _completePending() {
    this.pendingChatId = null
    this.pendingStatusUrl = null
    this.pendingSince = null
    this._clearPendingPoller()
    this._enableSubmit()
  }

  _resize() {
    if (!this.hasTextareaTarget) return
    const ta = this.textareaTarget
    ta.style.height = 'auto'
    const style = window.getComputedStyle(ta)
    const lineHeight = parseFloat(style.lineHeight) || 20
    const maxHeight = (lineHeight * 3)
    if (ta.scrollHeight <= maxHeight) {
      ta.style.overflowY = 'hidden'
      ta.style.height = `${ta.scrollHeight}px`
    } else {
      ta.style.overflowY = 'auto'
      ta.style.height = `${maxHeight}px`
    }
  }

  _updateSubmitState() {
    if (!this.hasSubmitTarget) return
    if (!this.signedInValue || !this.hasTextareaTarget || this.textareaTarget.hasAttribute('disabled')) {
      this._setSubmitDisabled(true)
      return
    }

    const hasContent = this.textareaTarget.value.trim().length > 0
    this._setSubmitDisabled(!hasContent)
  }

  _setSubmitDisabled(disabled) {
    if (!this.hasSubmitTarget) return
    if (disabled) {
      this.submitTarget.setAttribute('disabled', '')
    } else {
      this.submitTarget.removeAttribute('disabled')
    }
  }

  _scrollHistoryToBottom() {
    const h = this.historyTarget
    h.scrollTop = h.scrollHeight
  }
}
