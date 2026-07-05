import { Controller } from "@hotwired/stimulus"

// Autocomplete fuer die DSL-Suche auf /tracks (Intent 43). Schlaegt abhaengig vom zuletzt
// getippten Token entweder Feldnamen oder passende Werte vor (TrackQuerySuggestions). Debounced,
// damit nicht bei jedem Tastendruck ein Request rausgeht.
export default class extends Controller {
  static targets = ["input", "list"]

  connect() {
    this.debounceTimeout = null
  }

  onInput() {
    clearTimeout(this.debounceTimeout)
    this.debounceTimeout = setTimeout(() => this.fetchSuggestions(), 200)
  }

  async fetchSuggestions() {
    const term = this.currentToken()
    if (!term) {
      this.hide()
      return
    }

    const response = await fetch(`/tracks/query_suggestions?term=${encodeURIComponent(term)}`)
    if (!response.ok) {
      this.hide()
      return
    }

    const { suggestions } = await response.json()
    this.render(suggestions)
  }

  currentToken() {
    const value = this.inputTarget.value
    const cursor = this.inputTarget.selectionStart
    return value.slice(0, cursor).split(" ").pop()
  }

  render(suggestions) {
    if (!suggestions || suggestions.length === 0) {
      this.hide()
      return
    }

    this.listTarget.innerHTML = suggestions
      .map((suggestion) => (
        `<button type="button" class="dropdown-item" data-action="click->search-suggestions#select">${suggestion}</button>`
      ))
      .join("")
    this.listTarget.classList.add("show")
  }

  select(event) {
    const value = this.inputTarget.value
    const cursor = this.inputTarget.selectionStart
    const before = value.slice(0, cursor)
    const after = value.slice(cursor)
    const tokenStart = before.lastIndexOf(" ") + 1

    this.inputTarget.value = `${before.slice(0, tokenStart)}${event.currentTarget.textContent}${after}`
    this.hide()
    this.inputTarget.focus()
  }

  hide() {
    this.listTarget.classList.remove("show")
    this.listTarget.innerHTML = ""
  }
}
