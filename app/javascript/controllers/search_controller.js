import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { url: String, delay: Number }
  static targets = ["input"]

  connect() {
    this.delayValue = this.delayValue || 300
    this._generation = (this._generation || 0) + 1
    this._timer = null
    this._abort = null
  }

  disconnect() {
    this._generation += 1
    if (this._timer) clearTimeout(this._timer)
    if (this._abort) this._abort.abort()
  }

  changed(event) {
    const generation = ++this._generation
    if (this._abort) this._abort.abort()
    const q = (event.target.value || '').trim()
    if (this._timer) clearTimeout(this._timer)
    this._timer = setTimeout(async () => {
      const base = this.urlValue || '/posts'
      const targetUrl = new URL(base, window.location.origin)
      const tagId = this.element.querySelector('input[name="tag_id"]')?.value
      if (tagId) targetUrl.searchParams.set('tag_id', tagId)
      if (q.length) targetUrl.searchParams.set('q', q)
      const url = targetUrl.pathname + targetUrl.search

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
        if (generation !== this._generation) return
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
        if (err?.name === 'AbortError' || generation !== this._generation) return
        window.location.href = url
      }
    }, this.delayValue)
  }
}
