import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "list", "chips"]

  connect() {
    this.timer = null
    // Track selected tag ids to prevent duplicates
    this.selectedIds = new Set(
      Array.from(this.chipsTarget.querySelectorAll("input[type=hidden]"))
           .map(i => i.value)
    )
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
          const items = data
            .filter(t => !this.selectedIds.has(String(t.id)))
            .map(t => `<div data-action="click->tag-input#choose" data-id="${t.id}" data-name="${t.name}">${t.name}</div>`)
          this.listTarget.innerHTML = items.join("") || ""
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
    const id   = e.currentTarget.dataset.id
    const name = e.currentTarget.dataset.name
    this._addChip(id, name)
    this.inputTarget.value = ""
    this.listTarget.innerHTML = ""
  }

  // Press Enter → create new tag via POST /tags then add as chip
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
        }
      })
  }

  remove(e) {
    const id = e.currentTarget.dataset.tagId
    this.selectedIds.delete(id)
    // Remove chip span and hidden input with this id
    this.chipsTarget.querySelectorAll(`[data-tag-id="${id}"]`).forEach(el => el.closest("span, input") ? el.closest("span")?.remove() : el.remove())
    this.chipsTarget.querySelectorAll(`input[data-tag-id="${id}"]`).forEach(el => el.remove())
  }

  _addChip(id, name) {
    if (this.selectedIds.has(String(id))) return
    this.selectedIds.add(String(id))

    const span = document.createElement("span")
    span.className = "inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-xs bg-indigo-100 text-indigo-800 border border-indigo-200"
    span.innerHTML = `${name} <button type="button" data-action="click->tag-input#remove" data-tag-id="${id}" class="text-indigo-500 hover:text-indigo-800 leading-none">&times;</button>`

    const hidden = document.createElement("input")
    hidden.type = "hidden"
    hidden.name = "post[tag_ids][]"
    hidden.value = id
    hidden.dataset.tagId = id

    this.chipsTarget.appendChild(span)
    this.chipsTarget.appendChild(hidden)
  }
}
