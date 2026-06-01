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

    const provider = this.providerSelectTarget.value
    const requiresApiKey = provider !== "ollama"
    const shouldRequireApiKey = requiresApiKey && !this.storedApiKeyValue

    this.apiKeyWrapperTarget.classList.toggle("hidden", !requiresApiKey)

    if (this.hasApiKeyInputTarget) {
      this.apiKeyInputTarget.required = shouldRequireApiKey
    }
  }
}
