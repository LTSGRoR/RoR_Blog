import { Controller } from "@hotwired/stimulus"
import Prism from "prismjs"
import "prismjs/components/prism-ruby"
import "prismjs/components/prism-javascript"
import "prismjs/components/prism-css"
import "prismjs/components/prism-bash"
import "prismjs/components/prism-markup"

// Attach data-controller="syntax-highlight" to any element containing
// ActionText-rendered rich text (e.g. the <div class="prose"> on show.html.erb).
// Prism will highlight every <code class="language-*"> block inside.
export default class extends Controller {
  connect() {
    Prism.highlightAllUnder(this.element)
  }
}
