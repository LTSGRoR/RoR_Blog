import { Controller } from "@hotwired/stimulus"
import Prism from "prismjs"
import "prismjs/components/prism-ruby"
import "prismjs/components/prism-javascript"
import "prismjs/components/prism-css"
import "prismjs/components/prism-bash"
import "prismjs/components/prism-markup"

export default class extends Controller {
  connect() {
    this.observer = new MutationObserver(this.handleMutations.bind(this))
    this.observer.observe(document.body, { childList: true, subtree: true })

    // Highlight any existing code blocks
    this.highlightAll()

    // Trix / ActionText may insert content - listen for attachment events too
    document.addEventListener("trix-initialize", () => this.highlightAll())
  }

  disconnect() {
    this.observer.disconnect()
  }

  handleMutations(mutationsList) {
    for (const m of mutationsList) {
      for (const node of m.addedNodes) {
        if (node.nodeType !== Node.ELEMENT_NODE) continue
        if (node.matches && node.matches('pre') ) {
          this.highlightAll(node)
        } else if (node.querySelector && node.querySelector('pre')) {
          this.highlightAll(node)
        }
      }
    }
  }

  highlightAll(root = document) {
    const codes = root.querySelectorAll('pre code')
    codes.forEach((el) => Prism.highlightElement(el))
  }
}
