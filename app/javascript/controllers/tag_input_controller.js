import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "list"]

  connect() {
    this.timer = null
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
          this.listTarget.innerHTML = data.map(t => `<div data-action="click->tag-input#choose" data-id="${t.id}" data-name="${t.name}">${t.name}</div>`).join("")
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
    const id = e.currentTarget.dataset.id
    const name = e.currentTarget.dataset.name
    this.inputTarget.value = name
    let input = document.createElement('input')
    input.type = 'hidden'
    input.name = 'post[tag_ids][]'
    input.value = id
    this.element.appendChild(input)
    this.listTarget.innerHTML = ''
  }
}
