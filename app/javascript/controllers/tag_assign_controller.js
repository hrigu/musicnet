import { Controller } from "@hotwired/stimulus"

// Manuelles Zuweisen eines Tags an einen Track (Intent 79: volles Formular mit Kategorie-/
// Staerke-Schritten auf der Track-Detailseite; Intent 83: reduzierter Modus fuers Inline-Widget
// auf /tracks, siehe existingOnlyValue unten).
// Voller Ablauf: Livesuche nach bestehenden Tags (inkl. Kategorie, ueber TagsController#search) -
// waehlt der DJ einen Treffer, geht es direkt zur Staerke; tippt er stattdessen einen neuen Namen
// und waehlt "Neuer Tag", kommt zuerst noch die Kategorie-Auswahl dazwischen. Alle Zwischenschritte
// sind rein clientseitig, es gibt nur einen einzigen Submit am Ende (POST /track_tags).
export default class extends Controller {
  static targets = [
    "openButton", "panel", "stepSearch", "stepCategory", "stepStrength",
    "searchInput", "results", "categorySelect", "newTagLabel", "chosenTagLabel",
    "strengthInput", "tagIdField", "tagNameField", "categoryIdField"
  ]

  // existingOnly (Intent 83, Kategorie-Schritt fuer neue Tags seit Intent 90): kein
  // Staerke-Schritt - sowohl ein bestehender Treffer als auch ein neu angelegtes Tag werden
  // sofort mit der im Formular fest hinterlegten Staerke (5) abgeschickt. trackId blendet in der
  // Live-Suche bereits am Track zugewiesene Tags aus.
  static values = { existingOnly: Boolean, trackId: Number }

  open() {
    this.panelTarget.classList.remove("d-none")
    this.openButtonTarget.classList.add("d-none")
    this.searchInputTarget.focus()
  }

  // Schliesst das Widget komplett wieder (Escape oder Klick ausserhalb, Intent 83) - im vollen
  // Modus (Track-Detailseite) gibt es dafuer bisher keine Bedienung, daher nur dort verdrahtet
  // (data-action in tracks/_tag_assign_inline.erb), nicht generell in diesem Controller erzwungen.
  close() {
    this.hideResults()
    this.searchInputTarget.value = ""
    this.tagIdFieldTarget.value = ""
    this.panelTarget.classList.add("d-none")
    this.openButtonTarget.classList.remove("d-none")
  }

  // composedPath() statt element.contains(event.target) (Intent 90): selectNew() entfernt den
  // geklickten "Neuer Tag"-Button per hideResults() aus dem DOM, bevor der Klick zu diesem
  // window-weiten Listener durchgeblubbert ist - contains() liefert fuer ein bereits entferntes
  // Element faelschlich false, obwohl der Klick eindeutig innerhalb passierte, und schloss das
  // Panel sofort wieder zu. composedPath() haelt den Ereignis-Pfad zum Zeitpunkt des Klicks fest,
  // unabhaengig von spaeteren DOM-Mutationen.
  outsideClick(event) {
    if (this.panelTarget.classList.contains("d-none")) return
    if (event.composedPath().includes(this.element)) return

    this.close()
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
    let url = `/tags/search?term=${encodeURIComponent(term)}`
    if (this.hasTrackIdValue) url += `&track_id=${this.trackIdValue}`

    const response = await fetch(url)
    if (!response.ok) {
      this.hideResults()
      return
    }

    this.renderResults(await response.json(), term)
  }

  // Jedes Ergebnis bekommt einen data-index, damit Pfeiltasten/Enter dasselbe Element wie ein
  // Mausklick treffen koennen (onSearchKeydown loest button.click() aus statt die Auswahl-Logik
  // zu duplizieren). "Neuer Tag" erscheint seit Intent 90 auch im existingOnly-Modus (Inline-
  // Widget) - dort ohne Staerke-Schritt danach, siehe confirmCategory.
  renderResults(tags, term) {
    const items = tags.map((tag) => (
      `<button type="button" class="list-group-item list-group-item-action" data-action="tag-assign#selectExisting" data-tag-id="${tag.id}" data-tag-name="${tag.name}">${tag.name} <span class="text-muted small">(${tag.category})</span></button>`
    ))
    items.push(
      `<button type="button" class="list-group-item list-group-item-action" data-action="tag-assign#selectNew" data-tag-name="${term}">Neuer Tag: „${term}“</button>`
    )

    if (items.length === 0) {
      // Bewusst keine ".list-group-item"-Klasse - sonst wuerde die Pfeiltasten-/Enter-Navigation
      // in onSearchKeydown/highlightActive diesen reinen Hinweistext als waehlbaren Eintrag sehen.
      this.resultsTarget.innerHTML = `<div class="p-2 text-muted small">Keine Treffer</div>`
      this.resultsTarget.classList.remove("d-none")
      this.activeIndex = -1
      return
    }

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
    this.searchInputTarget.value = tagName
    this.hideResults()

    // existingOnly (Intent 83): kein Staerke-Schritt - das Formular traegt die Staerke schon fest
    // als verstecktes Feld (5), ein Treffer wird also direkt abgeschickt.
    if (this.existingOnlyValue) {
      this.panelTarget.requestSubmit()
      return
    }

    this.tagNameFieldTarget.value = ""
    this.categoryIdFieldTarget.value = ""
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

  // existingOnly (Intent 90): kein Staerke-Schritt fuer ein neu angelegtes Tag - genau wie bei
  // einem bestehenden Treffer wird sofort mit der fest hinterlegten Staerke (5) abgeschickt.
  confirmCategory(event) {
    event?.preventDefault()
    this.tagNameFieldTarget.value = this.pendingTagName
    this.categoryIdFieldTarget.value = this.categorySelectTarget.value
    this.stepCategoryTarget.classList.add("d-none")

    if (this.existingOnlyValue) {
      this.panelTarget.requestSubmit()
      return
    }

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
  // zurueck und geht zur Suche zurueck, statt das ganze Widget zu schliessen. hasStepStrengthTarget
  // (Intent 90): das Inline-Widget rendert keinen Staerke-Schritt, ein direkter Zugriff auf
  // stepStrengthTarget wuerde dort mit "Missing target element" abbrechen.
  backToSearch() {
    this.pendingTagName = null
    this.tagIdFieldTarget.value = ""
    this.tagNameFieldTarget.value = ""
    this.categoryIdFieldTarget.value = ""
    this.stepCategoryTarget.classList.add("d-none")
    if (this.hasStepStrengthTarget) this.stepStrengthTarget.classList.add("d-none")
    this.stepSearchTarget.classList.remove("d-none")
    this.searchInputTarget.value = ""
    this.searchInputTarget.focus()
  }
}
