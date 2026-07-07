import { Controller } from "@hotwired/stimulus"

// Manuelles Zuweisen eines Tags an einen Track von der Track-Detailseite aus (Intent 79).
// Ablauf: Livesuche nach bestehenden Tags (inkl. Kategorie, ueber TagsController#search) - waehlt
// der DJ einen Treffer, geht es direkt zur Staerke; tippt er stattdessen einen neuen Namen und
// waehlt "Neuer Tag", kommt zuerst noch die Kategorie-Auswahl dazwischen. Alle Zwischenschritte
// sind rein clientseitig, es gibt nur einen einzigen Submit am Ende (POST /track_tags).
export default class extends Controller {
  static targets = [
    "openButton", "panel", "stepSearch", "stepCategory", "stepStrength",
    "searchInput", "results", "categorySelect", "newTagLabel", "chosenTagLabel",
    "strengthInput", "tagIdField", "tagNameField", "categoryIdField"
  ]

  open() {
    this.panelTarget.classList.remove("d-none")
    this.openButtonTarget.classList.add("d-none")
    this.searchInputTarget.focus()
  }

  onInput() {
    clearTimeout(this.debounceTimeout)
    this.tagIdFieldTarget.value = ""

    const term = this.searchInputTarget.value.trim()
    if (!term) {
      this.hideResults()
      return
    }

    this.debounceTimeout = setTimeout(() => this.fetchResults(term), 200)
  }

  async fetchResults(term) {
    const response = await fetch(`/tags/search?term=${encodeURIComponent(term)}`)
    if (!response.ok) {
      this.hideResults()
      return
    }

    this.renderResults(await response.json(), term)
  }

  // Jedes Ergebnis (inkl. des immer angehaengten "Neuer Tag"-Eintrags) bekommt einen
  // data-index, damit Pfeiltasten/Enter dasselbe Element wie ein Mausklick treffen koennen
  // (onSearchKeydown loest button.click() aus statt die Auswahl-Logik zu duplizieren).
  renderResults(tags, term) {
    const items = tags.map((tag) => (
      `<button type="button" class="list-group-item list-group-item-action" data-action="tag-assign#selectExisting" data-tag-id="${tag.id}" data-tag-name="${tag.name}">${tag.name} <span class="text-muted small">(${tag.category})</span></button>`
    ))
    items.push(
      `<button type="button" class="list-group-item list-group-item-action" data-action="tag-assign#selectNew" data-tag-name="${term}">Neuer Tag: „${term}“</button>`
    )
    this.resultsTarget.innerHTML = items
      .map((html, index) => html.replace("<button ", `<button data-index="${index}" `))
      .join("")
    this.resultsTarget.classList.remove("d-none")
    // Erster Treffer ist sofort per Enter waehlbar, ohne dass zuerst Pfeil-runter gedrueckt
    // werden muss - der haeufigste Fall (ein einzelner passender Tag) braucht so nur Tippen+Enter.
    this.activeIndex = 0
    this.highlightActive()
  }

  hideResults() {
    this.resultsTarget.classList.add("d-none")
    this.resultsTarget.innerHTML = ""
    this.activeIndex = -1
  }

  highlightActive() {
    this.resultsTarget.querySelectorAll(".list-group-item").forEach((button, index) => {
      button.classList.toggle("active", index === this.activeIndex)
    })
  }

  // Pfeil hoch/runter bewegt die Markierung, Enter waehlt den markierten Eintrag (letzter
  // Eintrag ist immer "Neuer Tag"), Escape schliesst die Liste - komplette Tastaturbedienung
  // der Livesuche ohne Maus.
  onSearchKeydown(event) {
    if (this.resultsTarget.classList.contains("d-none")) return

    const items = this.resultsTarget.querySelectorAll(".list-group-item")
    if (event.key === "ArrowDown") {
      event.preventDefault()
      this.activeIndex = Math.min(this.activeIndex + 1, items.length - 1)
      this.highlightActive()
    } else if (event.key === "ArrowUp") {
      event.preventDefault()
      this.activeIndex = Math.max(this.activeIndex - 1, 0)
      this.highlightActive()
    } else if (event.key === "Enter") {
      event.preventDefault()
      items[this.activeIndex]?.click()
    } else if (event.key === "Escape") {
      this.hideResults()
    }
  }

  selectExisting(event) {
    const { tagId, tagName } = event.currentTarget.dataset
    this.tagIdFieldTarget.value = tagId
    this.tagNameFieldTarget.value = ""
    this.categoryIdFieldTarget.value = ""
    this.searchInputTarget.value = tagName
    this.hideResults()
    this.showStrengthStep(tagName)
  }

  selectNew(event) {
    this.pendingTagName = event.currentTarget.dataset.tagName
    this.tagIdFieldTarget.value = ""
    this.hideResults()
    this.newTagLabelTarget.textContent = this.pendingTagName
    this.stepSearchTarget.classList.add("d-none")
    this.stepCategoryTarget.classList.remove("d-none")
  }

  confirmCategory(event) {
    event?.preventDefault()
    this.tagNameFieldTarget.value = this.pendingTagName
    this.categoryIdFieldTarget.value = this.categorySelectTarget.value
    this.stepCategoryTarget.classList.add("d-none")
    this.showStrengthStep(this.pendingTagName)
  }

  showStrengthStep(tagName) {
    this.chosenTagLabelTarget.textContent = tagName
    this.stepSearchTarget.classList.add("d-none")
    this.stepStrengthTarget.classList.remove("d-none")
    this.strengthInputTarget.focus()
  }

  // Abbruchmoeglichkeit fuer den Kategorie- und den Staerke-Schritt (z.B. wenn beim zweiten
  // Schritt auffaellt, dass das falsche Tag gewaehlt wurde) - setzt die bisherige Auswahl
  // zurueck und geht zur Suche zurueck, statt das ganze Widget zu schliessen.
  backToSearch() {
    this.pendingTagName = null
    this.tagIdFieldTarget.value = ""
    this.tagNameFieldTarget.value = ""
    this.categoryIdFieldTarget.value = ""
    this.stepCategoryTarget.classList.add("d-none")
    this.stepStrengthTarget.classList.add("d-none")
    this.stepSearchTarget.classList.remove("d-none")
    this.searchInputTarget.value = ""
    this.searchInputTarget.focus()
  }
}
