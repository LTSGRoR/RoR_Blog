import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["textarea", "submit", "history", "spinner", "icon", "clearHistory", "sessions", "sessionTitle", "listView", "chatView", "back", "sessionError", "newSession"]
  static values = { signedIn: Boolean, historyUrl: String, sessionsUrl: String, storageKey: String }

  connect() {
    this.url = null
    this._view = 'list'
    if (this.hasNewSessionTarget) this.newSessionTarget.disabled = true
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
        if (!this._historyBefore) this._scrollHistoryToBottom()
      })
      this._observer.observe(this.historyTarget, { childList: true, subtree: true })
    }
  }

  disconnect() {
    this.element.removeEventListener('ai:open', this._eventHandler)
    document.removeEventListener('keydown', this._keyHandler)
    if (this._observer) this._observer.disconnect()
    this._clearPendingPoller()
    this._historyRequest?.abort()
    this._sessionsRequest?.abort()
  }

  open(event) {
    const detail = event?.detail || {}
    this.url = detail.url || this.url
    this._previouslyFocused = document.activeElement
    this.element.classList.remove('hidden')
    if (this.signedInValue && this.hasTextareaTarget) {
      this.textareaTarget.removeAttribute('disabled')
      if (this._view === 'chat') this.textareaTarget.focus()
      else this.newSessionTarget.focus()
      this._updateSubmitState()
    } else if (this.hasTextareaTarget) {
      this.textareaTarget.setAttribute('disabled', '')
      this._setSubmitDisabled(true)
    }
    if (this.signedInValue && !this._sessionsLoaded) this.loadSessions()
    else if (this.signedInValue && this._view === 'chat' && !this._historyLoaded) this.loadHistory()
    if (this.pendingChatId && this._view === 'chat') this._startPendingPoller()
    // scroll history to bottom
    if (this.hasHistoryTarget) {
      this._scrollHistoryToBottom()
    }
  }

  _sessionError(message = this.element.dataset.sessionsError) {
    if (!this.hasSessionErrorTarget) return
    this.sessionErrorTarget.textContent = message
    this.sessionErrorTarget.classList.remove('hidden')
  }

  _requestHeaders() {
    return { Accept: 'application/json', 'Content-Type': 'application/json', 'X-CSRF-Token': document.querySelector("meta[name='csrf-token']")?.content || '' }
  }

  async loadSessions(event) {
    event?.preventDefault()
    if (this._sessionsRequest) return
    const request = new AbortController()
    this._sessionsRequest = request
    try {
      const url = new URL(this.sessionsUrlValue, window.location.origin)
      if (event && this._sessionsBefore) url.searchParams.set('before', this._sessionsBefore)
      const response = await fetch(url, { headers: this._requestHeaders(), signal: request.signal })
      if (!response.ok) throw new Error()
      const json = await response.json()
      if (request.signal.aborted) return
      this._sessions = event ? [...(this._sessions || []), ...json.sessions] : json.sessions
      this._sessionsBefore = json.before
      this._sessionsLoaded = true
      this._renderSessions()
      if (!this.activeSessionId) {
        let remembered
        try { remembered = localStorage.getItem(this.storageKeyValue) } catch (_) {}
        let chosen = this._sessions.find(session => String(session.id) === remembered)
        // Restore an older conversation even when it is beyond the first list page.
        if (!chosen && /^\d+$/.test(remembered || '')) {
          const previous = await fetch(`${this.sessionsUrlValue}/${remembered}`, { headers: this._requestHeaders(), signal: request.signal })
          if (previous.ok) {
            chosen = await previous.json()
            this._sessions.unshift(chosen)
          }
        }
        if (request.signal.aborted) return
        chosen ||= this._sessions[0]
        if (chosen) this.selectSession(chosen.id)
        else this._setSidebar(true)
        this._renderSessions()
      }
      this.sessionErrorTarget.classList.add('hidden')
    } catch (_) {
      if (!request.signal.aborted) this._sessionError()
    } finally {
      if (this._sessionsRequest === request) this._sessionsRequest = null
      if (!this._changingSession) this.newSessionTarget.disabled = false
      if (this._view === 'list' && !this.element.classList.contains('hidden') && !this.element.contains(document.activeElement)) this.newSessionTarget.focus()
    }
  }

  toggleSidebar(event) {
    event?.preventDefault()
    this._setSidebar(!this._sidebarOpen)
    if (this._sidebarOpen) this.loadSessions()
  }

  _setSidebar(open) {
    this._sidebarOpen = open
    this.listViewTarget.classList.toggle('hidden', !open)
    this.listViewTarget.classList.toggle('flex', open)
    this.backTarget.setAttribute('aria-expanded', String(open))
    const label = open ? this.element.dataset.hideSidebarLabel : this.element.dataset.showSidebarLabel
    this.backTarget.setAttribute('aria-label', label)
    this.backTarget.title = label
    this.backTarget.classList.toggle('bg-slate-800', open)
    this.backTarget.classList.toggle('text-slate-100', open)
    if (open) this.newSessionTarget.focus()
    else this.backTarget.focus()
  }

  _showChat() {
    this._view = 'chat'
    this._setSidebar(false)
    this.textareaTarget.focus()
    this._resize()
    if (this.pendingChatId) this._startPendingPoller()
  }

  _renderSessions() {
    this.sessionsTarget.replaceChildren()
    if (!this._sessions?.length) {
      const empty = document.createElement('p')
      empty.className = 'px-4 py-10 text-center text-sm leading-6 text-slate-400'
      empty.textContent = this.element.dataset.noSessionsLabel
      this.sessionsTarget.appendChild(empty)
    }
    for (const session of this._sessions || []) {
      const row = document.createElement('div')
      row.className = 'flex min-w-0 items-center gap-2 rounded-xl border border-slate-800 bg-slate-900 p-1 hover:border-slate-600'
      const pick = document.createElement('button')
      pick.type = 'button'
      pick.textContent = session.title
      pick.className = 'min-h-11 min-w-0 flex-1 truncate rounded-lg px-2 text-left text-xs font-medium text-slate-200 focus-visible:ring-2 focus-visible:ring-red-400'
      pick.setAttribute('aria-pressed', String(session.id === this.activeSessionId))
      if (session.id === this.activeSessionId) row.classList.add('bg-slate-800')
      pick.addEventListener('click', () => this.selectSession(session.id))
      const remove = document.createElement('button')
      remove.type = 'button'
      remove.innerHTML = '<svg class="h-4 w-4" viewBox="0 0 20 20" fill="none" stroke="currentColor" stroke-width="1.5" aria-hidden="true"><path stroke-linecap="round" stroke-linejoin="round" d="M4 5h12M8 3h4M6 5l1 12h6l1-12M9 8v6m2-6v6" /></svg>'
      remove.setAttribute('aria-label', `${this.element.dataset.deleteLabel}: ${session.title}`)
      remove.className = 'inline-flex items-center justify-center h-11 w-11 shrink-0 rounded-lg text-lg text-slate-400 hover:text-red-300 focus-visible:ring-2 focus-visible:ring-red-400'
      remove.addEventListener('click', () => this.deleteSession(session))
      row.append(pick, remove)
      this.sessionsTarget.appendChild(row)
    }
    if (this._sessionsBefore) {
      const more = document.createElement('button')
      more.type = 'button'
      more.textContent = this.element.dataset.moreSessionsLabel
      more.className = 'min-h-11 w-full text-xs text-slate-300 underline'
      more.addEventListener('click', event => this.loadSessions(event))
      this.sessionsTarget.appendChild(more)
    }
  }

  selectSession(id) {
    if (this._submitting || this._clearing || this._changingSession) return
    if (this.activeSessionId === id && this._historyLoaded) {
      this._showChat()
      return
    }
    this._drafts ||= {}
    if (this.activeSessionId) this._drafts[this.activeSessionId] = this.textareaTarget.value
    this._historyRequest?.abort()
    this._historyRequest = null
    this._completePending()
    this.activeSessionId = id
    this._historyBefore = null
    this._historyLoaded = false
    this.historyTarget.replaceChildren()
    this.textareaTarget.value = this._drafts[id] || ''
    const session = this._sessions.find(item => item.id === id)
    this.sessionTitleTarget.textContent = session?.title || ''
    this._showChat()
    try { localStorage.setItem(this.storageKeyValue, String(id)) } catch (_) {}
    this._renderSessions()
    this._updateSubmitState()
    this.loadHistory()
  }

  async newSession(event) {
    event?.preventDefault()
    if (this._changingSession || this._submitting || this._clearing) return
    this._changingSession = true
    this.newSessionTarget.disabled = true
    try {
      const response = await fetch(this.sessionsUrlValue, { method: 'POST', headers: this._requestHeaders() })
      if (!response.ok) throw new Error()
      const session = await response.json()
      this._sessions = [session, ...(this._sessions || [])]
      this._changingSession = false
      this.selectSession(session.id)
    } catch (_) {
      this._sessionError()
    } finally {
      this._changingSession = false
      this.newSessionTarget.disabled = false
    }
  }

  async deleteSession(session) {
    if (this._changingSession || this._submitting || this._clearing || this._confirmingClear) return
    this._confirmingClear = true
    const accepted = await this._confirmMessage(this.element.dataset.deleteConfirm)
    this._confirmingClear = false
    if (!accepted || !this.element.isConnected) return
    this._changingSession = true
    try {
      const response = await fetch(session.delete_url, { method: 'DELETE', headers: this._requestHeaders() })
      if (!response.ok) throw new Error()
      this._sessions = this._sessions.filter(item => item.id !== session.id)
      this._changingSession = false
      if (this.activeSessionId === session.id) {
        this.activeSessionId = null
        this._historyRequest?.abort()
        this._historyRequest = null
        this._completePending()
        this._historyLoaded = false
        this.historyTarget.replaceChildren()
        this.sessionTitleTarget.textContent = this.element.dataset.newChatLabel
        this._updateSubmitState()
      }
      this._renderSessions()
      this.newSessionTarget.focus()
    } catch (_) {
      this._sessionError()
    } finally {
      this._changingSession = false
    }
  }

  _confirmMessage(message) {
    return new Promise(resolve => {
      const event = new CustomEvent('app:confirm', { cancelable: true, detail: { message, resolve } })
      if (document.dispatchEvent(event)) resolve(false)
    })
  }

  async loadHistory(event) {
    event?.preventDefault()
    if (this._historyRequest || !this.historyUrlValue || !this.hasHistoryTarget || !this.activeSessionId) return
    const request = new AbortController()
    this._historyRequest = request
    const sessionId = this.activeSessionId
    const before = this._historyBefore
    try {
      const url = new URL(this.historyUrlValue, window.location.origin)
      url.searchParams.set('chat_session_id', sessionId)
      if (before) url.searchParams.set('before', before)
      const response = await fetch(url, { headers: { Accept: 'application/json' }, signal: request.signal })
      if (!response.ok) throw new Error()
      const json = await response.json()
      if (request.signal.aborted || sessionId !== this.activeSessionId) return
      this.historyTarget.querySelector('[data-history-older]')?.remove()
      // A broadcast or submission may have arrived while history was loading.
      const wrapper = document.createElement('div')
      wrapper.innerHTML = json.html
      Array.from(wrapper.children).reverse().forEach(item => {
        if (!document.getElementById(item.id)) this.historyTarget.prepend(item)
      })
      if (!this.historyTarget.querySelector('[id^="chat_history_"]') && !json.before) {
        const empty = document.createElement('p')
        empty.dataset.historyEmpty = ''
        empty.className = 'm-auto text-xs text-slate-400 text-center'
        empty.textContent = this.element.dataset.emptyLabel
        this.historyTarget.appendChild(empty)
      }
      this._historyBefore = json.before
      this._historyLoaded = true
      if (json.before) {
        const button = document.createElement('button')
        button.type = 'button'
        button.textContent = this.element.dataset.olderLabel
        button.className = 'text-xs text-slate-300 underline py-2'
        button.dataset.historyOlder = ''
        button.dataset.action = 'ai-modal#loadHistory'
        this.historyTarget.prepend(button)
      }
      if (!before && json.pending) {
        this.pendingChatId = json.pending.id
        this.pendingStatusUrl = json.pending.status_url
        this.pendingSince = Date.now()
        if (!this.element.classList.contains('hidden') && this._view === 'chat') this._startPendingPoller()
      }
      this._updateSubmitState()
      if (!before) this._scrollHistoryToBottom()
    } catch (_error) {
      if (!request.signal.aborted) this._sessionError()
      // A later open retries history loading.
    } finally {
      if (this._historyRequest === request) this._historyRequest = null
    }
  }

  async clearHistory(event) {
    event?.preventDefault()
    if (!this.signedInValue || !this.activeSessionId || this._changingSession || this._clearing || this._submitting) return
    if (this._confirmingClear) return
    this._confirmingClear = true
    const accepted = await this._confirmMessage(this.element.dataset.clearConfirm)
    this._confirmingClear = false
    if (!accepted || !this.element.isConnected) return
    this._clearing = true
    if (this.hasClearHistoryTarget) this.clearHistoryTarget.disabled = true
    try {
      const response = await fetch(`${this.historyUrlValue}?chat_session_id=${this.activeSessionId}`, {
        method: 'DELETE',
        headers: { Accept: 'application/json', 'X-CSRF-Token': document.querySelector("meta[name='csrf-token']")?.content || '' }
      })
      if (!response.ok) throw new Error(this.element.dataset.clearError)
      this._historyRequest?.abort()
      this._historyRequest = null
      this._completePending()
      this._historyBefore = null
      this._historyLoaded = false
      this.historyTarget.replaceChildren()
      await this.loadHistory()
    } catch (_error) {
      this._sessionError(this.element.dataset.clearError)
    } finally {
      this._clearing = false
      if (this.hasClearHistoryTarget) this.clearHistoryTarget.disabled = false
    }
  }

  close() {
    this._clearPendingPoller()
    this.element.classList.add('hidden')
    if (this._previouslyFocused && this._previouslyFocused.isConnected) {
      this._previouslyFocused.focus()
    }
    this._previouslyFocused = null
  }

  async submit(e) {
    e?.preventDefault()
    if (!this.signedInValue || this._clearing || this._submitting) return
    if (!this.url || this._changingSession || this.pendingChatId) return

    const content = this.textareaTarget.value.trim()
    if (content.length === 0) return

    if (this.hasSubmitTarget) {
      this.submitTarget.setAttribute('disabled', '')
      this.submitTarget.classList.add('opacity-60', 'pointer-events-none')
      this.submitTarget.setAttribute('aria-disabled', 'true')
      this._showSpinner()
    }
    this._submitting = true
    if (this.hasClearHistoryTarget) this.clearHistoryTarget.disabled = true
    const token = document.querySelector("meta[name='csrf-token']")?.content

    try {
      if (!this.activeSessionId) {
        const response = await fetch(this.sessionsUrlValue, { method: 'POST', headers: this._requestHeaders() })
        if (!response.ok) throw new Error(this.element.dataset.sessionsError || 'Request failed')
        const session = await response.json()
        this._sessions = [session, ...(this._sessions || [])]
        this.activeSessionId = session.id
        this._historyBefore = null
        this._historyLoaded = true
        this.sessionTitleTarget.textContent = session.title
        try { localStorage.setItem(this.storageKeyValue, String(session.id)) } catch (_) {}
        this._renderSessions()
        this._showChat()
      }
      const resp = await fetch(this.url, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': token || '',
          'Accept': 'application/json'
        },
        body: JSON.stringify({ message: content, chat_session_id: this.activeSessionId })
      })

      if (!resp.ok) {
        const failure = await resp.json().catch(() => ({}))
        throw new Error(failure.error || 'Request failed')
      }

      const json = await resp.json()
      const session = this._sessions.find(item => item.id === this.activeSessionId)
      if (session && json.session_title) {
        session.title = json.session_title
        this.sessionTitleTarget.textContent = session.title
        this._renderSessions()
      }

      // If server returned rendered HTML for immediate feedback, append it
      if (json.html && this.hasHistoryTarget) {
        this.historyTarget.querySelector('[data-history-empty]')?.remove()
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
      if (this.hasHistoryTarget) {
        const errorMessage = document.createElement('p')
        errorMessage.setAttribute('role', 'alert')
        errorMessage.className = 'mb-3 text-sm text-red-300'
        errorMessage.textContent = err.message
        this.historyTarget.appendChild(errorMessage)
        this._scrollHistoryToBottom()
      }
      if (this.hasSubmitTarget) this._enableSubmit()
    } finally {
      this._submitting = false
      this._updateSubmitState()
      if (this.hasClearHistoryTarget) this.clearHistoryTarget.disabled = false
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
      this.element.querySelectorAll('a[href], button:not([disabled]), textarea:not([disabled]), input:not([disabled]), summary')
    ).filter(element => element.getClientRects().length > 0)
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
    this._pollRequest?.abort()
    this._pollRequest = null
    if (!this._pendingPoller) return
    clearInterval(this._pendingPoller)
    this._pendingPoller = null
  }

  async _pollPendingStatus() {
    if (!this.pendingChatId || !this.pendingStatusUrl) return

    if (this.pendingSince && Date.now() - this.pendingSince > 60000) {
      this._completePending()
      return
    }
    if (this._pollRequest) return
    const chatId = this.pendingChatId
    const request = new AbortController()
    this._pollRequest = request
    try {
      const resp = await fetch(this.pendingStatusUrl, {
        method: 'GET',
        headers: { Accept: 'application/json' },
        signal: request.signal
      })
      if (chatId !== this.pendingChatId || request.signal.aborted) return
      if (!resp.ok) {
        if ([401, 403, 404].includes(resp.status)) this._completePending()
        return
      }

      const json = await resp.json()
      if (chatId !== this.pendingChatId || request.signal.aborted) return
      if (json?.html) this._replacePendingItemHtml(json.html)
      if (json?.ready) this._completePending()
    } catch (_err) {
      // The independent deadline stops polling even when requests fail.
    } finally {
      if (this._pollRequest === request) this._pollRequest = null
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
    if (this.hasBackTarget) this.backTarget.disabled = !!(this._submitting || this._clearing)
    if (!this.hasSubmitTarget) return
    if (!this.signedInValue || this._submitting || this.pendingChatId || this._changingSession || this._clearing || !this.hasTextareaTarget || this.textareaTarget.hasAttribute('disabled')) {
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
