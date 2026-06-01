import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { url: String }

  connect() {
  }

  async ask(event) {
    event?.preventDefault()
    const btn = this.element.querySelector('button')
    if (btn) btn.setAttribute('disabled', '')

    try {
      const modal = document.getElementById('ai_chat_modal')
      let urlToSend = this.urlValue
      if (!urlToSend) {
        const m = window.location.pathname.match(/\/posts\/(\d+)(?:\/|$)/)
        urlToSend = m ? `/posts/${m[1]}/chat` : '/chat'
      }


      if (modal) {
        modal.dispatchEvent(new CustomEvent('ai:open', { detail: { url: urlToSend }, bubbles: true }))
      } else {
        // No modal present — navigate directly
        window.location.href = urlToSend
      }
    } catch (err) {
      console.error('[ai-fab] ask failed', err)
    } finally {
      if (btn) btn.removeAttribute('disabled')
    }
  }
}