import "trix"

// Rails ships Trix as a side-effect asset exposing window.Trix, rather than
// an ES module with a default export. A default import breaks app startup.
const Trix = window.Trix

// Trix's default paragraph renderer omits HTML attributes. A normal div
// block gives aligned paragraphs a container that serializes its class.
Trix.config.blockAttributes.alignment = {
  tagName: "div",
  group: false,
  test: element => /\brt-align-(left|center|right)\b/.test(element.className)
}

// Alignment is stored on the block, so it can coexist with headings, lists,
// quotes, code, and attachments without replacing their formatting.
for (const config of Object.values(Trix.config.blockAttributes)) {
  config.htmlAttributes = [...new Set([...(config.htmlAttributes || []), "class"])]
}

// Read the current page locale before Trix builds its toolbar/caption editor.
// Turbo may replace the head without re-evaluating this module.
function localizeTrix() {
  const translations = document.querySelector('meta[name="editor-translations"]')
  if (translations) Object.assign(Trix.config.lang, JSON.parse(translations.content))
}
localizeTrix()
document.addEventListener("trix-before-initialize", localizeTrix)
