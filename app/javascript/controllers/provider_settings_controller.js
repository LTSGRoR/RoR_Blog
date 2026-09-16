import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["providerSelect", "apiKeyWrapper", "apiKeyInput"]
  static values = { storedApiKey: Boolean }

  connect() {
    this.toggleApiKey()
  }

  providerChanged() {
    this.toggleApiKey()
  }

  toggleApiKey() {
    if (!this.hasProviderSelectTarget || !this.hasApiKeyWrapperTarget) return

    // Every supported provider (openai, gemini, claude, mistral) needs an API
    // key. Keep the wrapper visible; only skip *requiring* it when a key is
    // already stored (a blank input keeps the stored key).
    this.apiKeyWrapperTarget.classList.remove("hidden")

    if (this.hasApiKeyInputTarget) {
      this.apiKeyInputTarget.required = !this.storedApiKeyValue
    }
  }
}
