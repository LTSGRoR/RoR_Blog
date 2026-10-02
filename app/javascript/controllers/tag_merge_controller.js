import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "results"]
  static values = { url: String, empty: String, error: String }

  connect() {
    this.generation = (this.generation || 0) + 1
  }

  disconnect() {
    this.cancel()
  }

  cancel() {
    clearTimeout(this.timer)
    this.abort?.abort()
    this.generation = (this.generation || 0) + 1
  }

  search() {
    this.cancel()
    const generation = this.generation
    const query = this.inputTarget.value.trim()
    this.resultsTarget.replaceChildren()
    if (!query) return
    this.timer = setTimeout(async () => {
      this.abort = new AbortController()
      const url = new URL(this.urlValue, window.location.origin)
      url.searchParams.set("q", query)
      try {
        const response = await fetch(url, { headers: { Accept: "application/json" }, signal: this.abort.signal })
        if (!response.ok) throw new Error(`HTTP ${response.status}`)
        const tags = await response.json()
        if (generation !== this.generation) return
        this.resultsTarget.replaceChildren()
        tags.forEach(tag => {
          const button = document.createElement("button")
          button.type = "button"
          button.textContent = `#${tag.name}`
          button.dataset.name = tag.name
          button.dataset.action = "click->tag-merge#choose"
          button.className = "block h-10 min-h-10 w-full truncate px-3 py-2 text-left text-sm text-slate-700 hover:bg-red-50 focus:bg-red-50 focus:outline-none"
          this.resultsTarget.appendChild(button)
        })
        if (!tags.length) this.status(this.emptyValue)
      } catch (error) {
        if (error.name === "AbortError" || generation !== this.generation) return
        this.status(this.errorValue)
      }
    }, 200)
  }

  choose(event) {
    this.inputTarget.value = event.currentTarget.dataset.name
    this.clear()
  }

  status(message) {
    const text = document.createElement("p")
    text.textContent = message
    text.className = "px-3 py-2 text-sm text-slate-500"
    text.setAttribute("role", "status")
    this.resultsTarget.replaceChildren(text)
  }

  clear() {
    this.cancel()
    this.resultsTarget.replaceChildren()
  }

  closeOutside(event) {
    if (!this.element.contains(event.target)) this.clear()
  }
}
