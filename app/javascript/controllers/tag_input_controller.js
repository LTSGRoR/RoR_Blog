import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "list", "chips"]
  static values = { hiddenInputName: { type: String, default: "post[tag_ids][]" } }

  connect() {
    this.timer = null
    this.activeResultIndex = -1
    // Track selected tag ids to prevent duplicates
    this.selectedIds = new Set(
      Array.from(this.chipsTarget.querySelectorAll("input[type=hidden]"))
           .map(i => i.value)
    )

    this.ensureEmptyField()

    this.boundCloseOnOutsideClick = this.closeOnOutsideClick.bind(this)
    document.addEventListener("click", this.boundCloseOnOutsideClick)
  }

  disconnect() {
    document.removeEventListener("click", this.boundCloseOnOutsideClick)
  }

  search() {
    clearTimeout(this.timer)
    const q = this.inputTarget.value.trim()
    if (q.length === 0) {
      this.clearList()
      return
    }

    this.renderStatus("Searching tags", "Matching tags will appear here.")

    this.timer = setTimeout(() => {
      fetch(`/tags?q=${encodeURIComponent(q)}`, { headers: { "Accept": "application/json" } })
        .then(r => r.json())
        .then(data => {
          const items = data.filter(t => !this.selectedIds.has(String(t.id)))

          if (!items.length) {
            this.renderEmptyState(q)
            return
          }

          this.activeResultIndex = 0
          this.renderResults(items, q)
        })
        .catch(() => {
          this.renderStatus("Could not load tags", "Try again in a moment.")
        })
    }, 200)
  }

  handleKeydown(e) {
    if (e.key === "Escape") {
      e.preventDefault()
      this.clearList()
      return
    }

    if (e.key === "Enter") {
      const active = this.resultItems[this.activeResultIndex]
      if (active) {
        e.preventDefault()
        e.stopPropagation()
        active.click()
      } else {
        e.preventDefault()
        e.stopPropagation()
        this.createFromInput()
      }
      return
    }

    const items = this.resultItems
    if (!items.length) return

    if (e.key === "ArrowDown") {
      e.preventDefault()
      this.activeResultIndex = Math.min(this.activeResultIndex + 1, items.length - 1)
      this.syncActiveResult()
    } else if (e.key === "ArrowUp") {
      e.preventDefault()
      this.activeResultIndex = Math.max(this.activeResultIndex - 1, 0)
      this.syncActiveResult()
    }
  }

  choose(e) {
    const id   = e.currentTarget.dataset.id
    const name = e.currentTarget.dataset.name
    this._addChip(id, name)
    this.inputTarget.value = ""
    this.clearList()
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
          this.clearList()
        }
      })
  }

  remove(e) {
    const id = e.currentTarget.dataset.tagId
    this.selectedIds.delete(id)

    const chip = this.chipsTarget.querySelector(`span[data-tag-id="${id}"]`)
    chip?.remove()

    const hidden = this.chipsTarget.querySelector(`input[data-tag-id="${id}"]`)
    hidden?.remove()

    this.ensureEmptyField()
  }

  _addChip(id, name) {
    if (this.selectedIds.has(String(id))) return
    this.selectedIds.add(String(id))

    this.removeEmptyField()

    const span = document.createElement("span")
    span.dataset.tagId = id
    span.className = "inline-flex items-center gap-2 px-3 py-1 rounded-full text-xs font-medium bg-indigo-100 text-indigo-800 border border-indigo-200"
    span.style.marginRight = "0.5rem"

    const text = document.createTextNode(name)

    const button = document.createElement("button")
    button.type = "button"
    button.dataset.action = "click->tag-input#remove"
    button.dataset.tagId = id
    button.className = "text-sm leading-none text-indigo-400 hover:text-indigo-700"
    button.style.paddingLeft = "0.25rem"
    button.setAttribute("aria-label", "Remove tag")
    button.innerHTML = "&times;"

    span.appendChild(text)
    span.appendChild(button)

    const hidden = document.createElement("input")
    hidden.type = "hidden"
    hidden.name = this.hiddenInputNameValue
    hidden.value = id
    hidden.dataset.tagId = id

    this.chipsTarget.appendChild(span)
    this.chipsTarget.appendChild(hidden)
  }

  ensureEmptyField() {
    if (this.chipsTarget.querySelector(`input[name="${this.hiddenInputNameValue}"]`)) return

    const hidden = document.createElement("input")
    hidden.type = "hidden"
    hidden.name = this.hiddenInputNameValue
    hidden.value = ""
    hidden.dataset.emptyTagIds = "true"

    this.chipsTarget.appendChild(hidden)
  }

  removeEmptyField() {
    this.chipsTarget.querySelector('[data-empty-tag-ids="true"]')?.remove()
  }

  closeOnOutsideClick(e) {
    if (!this.element.contains(e.target)) {
      this.clearList()
    }
  }

  renderResults(items, _query) {
    this.listTarget.innerHTML = items.map((tag, index) => {
      const isActive = index === this.activeResultIndex
      const activeClasses = isActive ? "bg-indigo-50/80 text-indigo-700" : "text-slate-700 hover:bg-slate-50"

      return `
        <button
          type="button"
          data-action="click->tag-input#choose"
          data-id="${tag.id}"
          data-name="${tag.name}"
          class="flex w-full items-center justify-between gap-3 px-4 py-3 text-left transition-colors duration-150 ${activeClasses}"
        >
          <span class="block min-w-0 truncate text-sm font-medium">${tag.name}</span>
          <span class="h-2 w-2 rounded-full bg-slate-200"></span>
        </button>
      `
    }).join("")
  }

  renderEmptyState(query) {
    this.activeResultIndex = -1
    this.listTarget.innerHTML = `
      <div class="px-4 py-5">
        <p class="text-sm font-medium text-slate-700">No matching tags</p>
        <p class="mt-1 text-xs text-slate-500">Nothing matched "${this.escapeHtml(query)}".</p>
      </div>
    `
  }

  renderStatus(title, subtitle) {
    this.activeResultIndex = -1
    this.listTarget.innerHTML = `
      <div class="px-4 py-4">
        <p class="text-sm font-medium text-slate-700">${this.escapeHtml(title)}</p>
        <p class="mt-1 text-xs text-slate-500">${this.escapeHtml(subtitle)}</p>
      </div>
    `
  }

  clearList() {
    this.activeResultIndex = -1
    this.listTarget.innerHTML = ""
  }

  syncActiveResult() {
    this.resultItems.forEach((item, index) => {
      const active = index === this.activeResultIndex
      item.classList.toggle("bg-indigo-50", active)
      item.classList.toggle("text-indigo-700", active)
      item.classList.toggle("text-slate-700", !active)
      item.classList.toggle("hover:bg-slate-50", !active)
    })

    this.resultItems[this.activeResultIndex]?.scrollIntoView({ block: "nearest" })
  }

  escapeHtml(text) {
    return text
      .replaceAll("&", "&amp;")
      .replaceAll("<", "&lt;")
      .replaceAll(">", "&gt;")
      .replaceAll('"', "&quot;")
      .replaceAll("'", "&#39;")
  }

  get resultItems() {
    return Array.from(this.listTarget.querySelectorAll('button[data-action="click->tag-input#choose"]'))
  }
}
