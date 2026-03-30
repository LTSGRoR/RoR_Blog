import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { url: String, delay: Number }
  static targets = ["input"]

  connect() {
    this.delayValue = this.delayValue || 300
    this._timer = null
    console.log('[search] connected', { url: this.urlValue, delay: this.delayValue, hasInputTarget: this.hasInputTarget })
  }

  disconnect() {
    if (this._timer) clearTimeout(this._timer)
  }

  changed(event) {
    const q = (event.target.value || '').trim()
    if (this._timer) clearTimeout(this._timer)
    this._timer = setTimeout(async () => {
      const base = this.urlValue || '/posts'
      const url = q.length ? `${base}?q=${encodeURIComponent(q)}` : base
      const jsonUrl = q.length ? `${base}.json?q=${encodeURIComponent(q)}` : `${base}.json`

      console.log('[search] query', { q, url, jsonUrl })

      // Try to fetch JSON first to log raw JSON response (non-blocking)
      try {
        const jres = await fetch(jsonUrl, { headers: { Accept: 'application/json' }, credentials: 'same-origin' })
        if (jres.ok) {
          const jdata = await jres.json()
          console.log('[search] json response', jdata)
        } else {
          console.warn('[search] json fetch failed', jres.status)
        }
      } catch (e) {
        console.warn('[search] json fetch error', e)
      }

      try {
        const res = await fetch(url, { headers: { Accept: 'text/html' }, credentials: 'same-origin' })
        if (!res.ok) throw new Error(`HTTP ${res.status}`)
        const text = await res.text()
        const parser = new DOMParser()
        const doc = parser.parseFromString(text, 'text/html')
        const newResults = doc.getElementById('posts-results')
        const currentResults = document.getElementById('posts-results')

        if (newResults && currentResults) {
          currentResults.innerHTML = newResults.innerHTML
        } else {
          console.warn('[search] fragment not found, falling back to navigation')
          window.location.href = url
          return
        }

        window.history.replaceState({}, '', url)
      } catch (err) {
        console.error('[search] live search error', err)
        console.warn('Live search failed, falling back to navigation:', err)
        window.location.href = url
      }
    }, this.delayValue)
  }
}
