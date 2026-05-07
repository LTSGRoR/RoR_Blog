import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button", "container", "loader", "suggestions", "suggestionsList"]
  static values = {
    revisionId: Number,
    endpoint: String
  }

  connect() {
    // Controller is connected
  }

  async generateSuggestions() {
    this.buttonTarget.disabled = true
    this.loaderTarget?.classList.remove("hidden")

    try {
      const response = await fetch(this.endpointValue, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content
        }
      })

      if (!response.ok) {
        const error = await response.json()
        this.showError(error.error || "Failed to generate suggestions")
        return
      }

      const data = await response.json()
      this.displaySuggestions(data)
    } catch (error) {
      this.showError(`Error: ${error.message}`)
    } finally {
      this.buttonTarget.disabled = false
      this.loaderTarget?.classList.add("hidden")
    }
  }

  displaySuggestions(data) {
    if (!data.suggestions || data.suggestions.length === 0) {
      this.showError("No suggestions available")
      return
    }

    this.suggestionsTarget.classList.remove("hidden")
    this.suggestionsListTarget.innerHTML = ""

    data.suggestions.forEach((suggestion, index) => {
      const suggestionEl = document.createElement("div")
      suggestionEl.className = "p-3 mb-2 bg-blue-50 border border-blue-200 rounded cursor-pointer hover:bg-blue-100"
      suggestionEl.innerHTML = `
        <p class="text-sm text-blue-800">${this.escapeHtml(suggestion)}</p>
        <small class="text-blue-600">Click to use this suggestion</small>
      `
      suggestionEl.addEventListener("click", () => this.useSuggestion(suggestion))
      this.suggestionsListTarget.appendChild(suggestionEl)
    })

    // Show metadata
    const meta = document.createElement("div")
    meta.className = "mt-3 text-xs text-gray-500"
    meta.innerHTML = `Generated from ${data.similar_count} similar rejections`
    this.suggestionsListTarget.appendChild(meta)
  }

  useSuggestion(suggestion) {
    // Find the review_note textarea and insert the suggestion
    const textarea = document.querySelector("textarea[name*='review_note']")
    if (textarea) {
      if (textarea.value.trim()) {
        textarea.value += "\n\n" + suggestion
      } else {
        textarea.value = suggestion
      }
      textarea.focus()
    }
  }

  showError(message) {
    this.suggestionsTarget.classList.remove("hidden")
    this.suggestionsListTarget.innerHTML = `<div class="p-3 bg-red-50 border border-red-200 rounded"><p class="text-sm text-red-800">${this.escapeHtml(message)}</p></div>`
  }

  escapeHtml(text) {
    const div = document.createElement("div")
    div.textContent = text
    return div.innerHTML
  }
}
