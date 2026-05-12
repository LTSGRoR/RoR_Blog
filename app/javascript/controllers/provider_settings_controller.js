import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["providerSelect", "apiKeyWrapper", "apiKeyInput"]

  connect() {
    this.toggleApiKey()
  }

  providerChanged() {
    this.toggleApiKey()
  }

  toggleApiKey() {
    if (!this.hasProviderSelectTarget || !this.hasApiKeyWrapperTarget) return

    const provider = this.providerSelectTarget.value
    const requiresApiKey = provider !== "ollama"

    this.apiKeyWrapperTarget.classList.toggle("hidden", !requiresApiKey)

    if (this.hasApiKeyInputTarget) {
      this.apiKeyInputTarget.required = requiresApiKey
    }
  }
}
