import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["textarea", "submit", "history", "spinner", "icon"]
  static values = { signedIn: Boolean }

  connect() {
    this.url = null
    this.element.addEventListener('ai:open', (e) => this.open(e))
    document.addEventListener('keydown', (e) => {
      if (e.key === 'Escape') this.close()
    })

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
      this._observer = new MutationObserver((mutations) => {
        this._scrollHistoryToBottom()
        this._checkPendingComplete()
      })
      this._observer.observe(this.historyTarget, { childList: true, subtree: true })
    }
  }

  disconnect() {
    if (this._observer) this._observer.disconnect()
    this._clearPendingPoller()
  }

  open(event) {
    const detail = event?.detail || {}
    this.url = detail.url || this.url
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

  _checkPendingComplete() {
    if (!this.pendingChatId) return
    const el = document.getElementById(`chat_history_${this.pendingChatId}`)
    if (!el) return
    const text = (el.innerText || '').trim().toLowerCase()
    // If the placeholder "Generating" is gone, job likely completed.
    if (!text.includes('generating')) {
      this._completePending()
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
      this._checkPendingComplete()
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
