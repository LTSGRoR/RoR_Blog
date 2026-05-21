import { Controller } from "@hotwired/stimulus"
import { normalizeTimeZone } from "controllers/time_zone_aliases"

const FORMATS = {
  short: {
    month: "short",
    day: "2-digit",
    year: "numeric",
    hour: "2-digit",
    minute: "2-digit",
    hour12: true,
  },
}

export default class extends Controller {
  static values = {
    format: { type: String, default: "short" },
  }

  connect() {
    const timestamp = this.parseTimestamp()
    if (!timestamp) return

    const timeZone = this.detectTimeZone()
    if (!timeZone) return

    const formatted = this.formatTimestamp(timestamp, timeZone)
    if (!formatted) return

    this.element.textContent = formatted
  }

  parseTimestamp() {
    const rawValue = this.element.getAttribute("datetime")
    if (!rawValue) return null

    const timestamp = new Date(rawValue)
    return Number.isNaN(timestamp.getTime()) ? null : timestamp
  }

  detectTimeZone() {
    const detectedTimeZone = Intl.DateTimeFormat().resolvedOptions().timeZone || "UTC"
    return normalizeTimeZone(detectedTimeZone)
  }

  formatTimestamp(timestamp, timeZone) {
    const options = FORMATS[this.formatValue]
    if (!options) return null

    const formatter = new Intl.DateTimeFormat("en-US", { ...options, timeZone })
    const parts = formatter.formatToParts(timestamp)
    const values = {}

    parts.forEach(({ type, value }) => {
      if (type !== "literal") values[type] = value
    })

    if (!values.month || !values.day || !values.year || !values.hour || !values.minute || !values.dayPeriod) {
      return null
    }

    return `${values.month} ${values.day}, ${values.year} ${values.hour}:${values.minute} ${values.dayPeriod}`
  }
}