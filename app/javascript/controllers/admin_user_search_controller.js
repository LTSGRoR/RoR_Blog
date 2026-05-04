import { Controller } from "@hotwired/stimulus"

function debounce(fn, wait) {
  let t
  return function(...args) {
    clearTimeout(t)
    t = setTimeout(() => fn.apply(this, args), wait)
  }
}

export default class extends Controller {
  connect() {
    this.submit = debounce(this.submit.bind(this), 300)
  }

  search(event) {
    if (event?.type === 'keydown' && event.key === 'Enter') {
      event.preventDefault()
    }
    this.submit()
  }

  submit() {
    this.element.requestSubmit()
  }
}