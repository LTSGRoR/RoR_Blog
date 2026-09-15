import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { url: String, delay: Number }
  static targets = ["input"]

  connect() {
    this.delayValue = this.delayValue || 300
    this._timer = null
    this._abort = null
  }

  disconnect() {
    if (this._timer) clearTimeout(this._timer)
    if (this._abort) this._abort.abort()
  }

  changed(event) {
    const q = (event.target.value || '').trim()
    if (this._timer) clearTimeout(this._timer)
    this._timer = setTimeout(async () => {
      const base = this.urlValue || '/posts'
      const url = q.length ? `${base}?q=${encodeURIComponent(q)}` : base

      // Cancel any in-flight search so a slow older response can never
      // overwrite a newer one.
      if (this._abort) this._abort.abort()
      this._abort = new AbortController()

      try {
        const res = await fetch(url, {
          headers: { Accept: 'text/html' },
          credentials: 'same-origin',
          signal: this._abort.signal
        })
        if (!res.ok) throw new Error(`HTTP ${res.status}`)
        const text = await res.text()
        const parser = new DOMParser()
        const doc = parser.parseFromString(text, 'text/html')
        const newResults = doc.getElementById('posts-results')
        const currentResults = document.getElementById('posts-results')

        if (newResults && currentResults) {
          currentResults.innerHTML = newResults.innerHTML
        } else {
          window.location.href = url
          return
        }

        window.history.replaceState({}, '', url)
      } catch (err) {
        // An aborted request is us superseding ourselves — not an error.
        if (err?.name === 'AbortError') return
        window.location.href = url
      }
    }, this.delayValue)
  }
}
