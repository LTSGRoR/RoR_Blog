import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "list", "chips"]

  connect() {
    this.timer = null
    this.selectedIds = new Set(
      Array.from(this.chipsTarget.querySelectorAll("span[data-tag-id]"))
           .map(s => s.dataset.tagId)
    )
    this._clickOutside = (e) => {
      if (!this.element.contains(e.target)) this.listTarget.innerHTML = ""
    }
    document.addEventListener("click", this._clickOutside)
  }

  disconnect() {
    document.removeEventListener("click", this._clickOutside)
  }

  search() {
    clearTimeout(this.timer)
    const q = this.inputTarget.value.trim()
    if (q.length === 0) { this.listTarget.innerHTML = ""; return }

    this.listTarget.innerHTML = `<div class="px-4 py-2 text-xs text-slate-400 italic select-none">Searching…</div>`

    this.timer = setTimeout(() => {
      fetch(`/tags?q=${encodeURIComponent(q)}`, { headers: { "Accept": "application/json" } })
        .then(r => r.json())
        .then(data => {
          const available = data.filter(t => !this.selectedIds.has(String(t.id)))
          const exactMatch = data.some(t => t.name.toLowerCase() === q.toLowerCase())
          const itemClass = "px-4 py-2 text-sm text-slate-700 cursor-pointer hover:bg-slate-50"
          const items = available.map(t =>
            `<div class="${itemClass}" data-action="click->tag-input#choose" data-id="${t.id}" data-name="${this._esc(t.name)}">${this._esc(t.name)}</div>`
          )
          if (!exactMatch && q.length > 0) {
            const createClass = "px-4 py-2 text-sm text-indigo-600 font-medium cursor-pointer hover:bg-indigo-50 border-t border-slate-100"
            items.push(
              `<div class="${createClass}" data-action="click->tag-input#createFromInput">+ Create <span class="font-semibold">"${this._esc(q)}"</span></div>`
            )
          }
          this.listTarget.innerHTML = items.join("")
        })
    }, 200)
  }

  handleKeydown(e) {
    const items = Array.from(this.listTarget.querySelectorAll("[data-action]"))

    if (e.key === "Escape") {
      e.preventDefault()
      this.listTarget.innerHTML = ""
      return
    }

    if (!items.length) return

    const activeClass = ["bg-indigo-50", "!text-indigo-700"]
    const active = this.listTarget.querySelector(".bg-indigo-50")
    const idx = active ? items.indexOf(active) : -1

    if (e.key === "ArrowDown") {
      e.preventDefault()
      active?.classList.remove(...activeClass)
      items[Math.min(idx + 1, items.length - 1)].classList.add(...activeClass)
    } else if (e.key === "ArrowUp") {
      e.preventDefault()
      active?.classList.remove(...activeClass)
      if (idx > 0) items[idx - 1].classList.add(...activeClass)
    } else if (e.key === "Enter") {
      e.preventDefault()
      if (active) {
        active.click()
      } else {
        this.createFromInput()
      }
    }
  }

  choose(e) {
    const { id, name } = e.currentTarget.dataset
    this._addChip(id, name)
    this.inputTarget.value = ""
    this.listTarget.innerHTML = ""
    this.inputTarget.focus()
  }

  createFromInput() {
    const name = this.inputTarget.value.trim()
    if (!name) return
    fetch("/tags", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content
      },
      body: JSON.stringify({ name })
    })
      .then(r => r.json())
      .then(tag => {
        if (tag.id) {
          this._addChip(String(tag.id), tag.name)
          this.inputTarget.value = ""
          this.listTarget.innerHTML = ""
          this.inputTarget.focus()
        }
      })
  }

  remove(e) {
    const id = e.currentTarget.dataset.tagId
    this.selectedIds.delete(String(id))
    this.chipsTarget.querySelector(`span[data-tag-id="${id}"]`)?.remove()
  }

  _addChip(id, name) {
    if (this.selectedIds.has(String(id))) return
    this.selectedIds.add(String(id))

    const span = document.createElement("span")
    span.dataset.tagId = id
    span.className = "inline-flex items-center gap-2 px-3 py-1 rounded-full text-xs font-medium bg-indigo-100 text-indigo-800 border border-indigo-200"
    span.innerHTML = `${this._esc(name)} <button type="button" data-action="click->tag-input#remove" data-tag-id="${id}" class="text-sm leading-none text-indigo-400 hover:text-indigo-700" aria-label="Remove tag">&times;</button><input type="hidden" name="post[tag_ids][]" value="${id}" />`

    this.chipsTarget.appendChild(span)
  }

  _esc(str) {
    return String(str)
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;")
  }
}
