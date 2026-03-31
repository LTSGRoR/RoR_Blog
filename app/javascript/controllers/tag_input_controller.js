import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "list"]

  connect() {
    this.timer = null
  }

  search() {
    clearTimeout(this.timer)
    this.timer = setTimeout(() => {
      const q = this.inputTarget.value.trim()
      if (q.length === 0) { this.listTarget.innerHTML = ""; return }
      fetch(`/tags?q=${encodeURIComponent(q)}`, { headers: { "Accept": "application/json" } })
        .then(r => r.json())
        .then(data => {
          this.listTarget.innerHTML = data.map(t => `<div data-action="click->tag-input#choose" data-id="${t.id}" data-name="${t.name}">${t.name}</div>`).join("")
        })
    }, 200)
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
