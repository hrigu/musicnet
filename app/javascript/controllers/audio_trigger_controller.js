import { Controller } from "@hotwired/stimulus"

// Sitzt auf dem Play-/Vorhoer-Button einer Track-Zeile. Kennt weder den globalen Player noch den
// Cue-Player direkt (die liegen an einer ganz anderen Stelle im DOM) - dispatcht stattdessen ein
// Event auf document, auf das audio_player_controller.js bzw. cue_player_controller.js lauschen
// (Intent 51). Entkoppelt, da Buttons ueberall verstreut sind (Tracks-Tabelle, Playlist-Tracks-
// Tabelle, Track-Detailseite). Das Einreihen in die Queue laeuft seit Intent 42 ueber einen
// normalen button_to-POST-Request statt ueber diesen Controller.
export default class extends Controller {
  static values = { url: String, name: String, mode: { type: String, default: "play" } }

  // Nur Vorhoer-Buttons (mode: "cue") zeigen den Live-Zustand (Intent 51 Nachtrag) - Play-Buttons
  // bleiben laut CLAUDE.md-Vorgabe bewusst immer "▶", kein Zustand pro Zeile.
  //
  // Sync auf turbo:load statt (nur) beim Verbinden (Nachtrag): waehrend einer Turbo-Drive-
  // Navigation verbinden sich die neuen Zeilen-Buttons, BEVOR das permanente Cue-Player-Element
  // wieder in das neue Dokument eingehaengt ist - ein direkter DOM-Read zum Zeitpunkt von
  // connect() findet das <audio>-Element daher manchmal noch gar nicht (empirisch verifiziert).
  // turbo:load feuert erst, wenn Turbo die Seite inkl. aller permanenten Elemente fertig
  // gerendert hat, und deckt sowohl den allerersten Seitenaufruf als auch jede weitere
  // Drive-Navigation ab.
  connect() {
    if (this.modeValue !== "cue") return

    this.isActiveCueTrack = false
    this.handleCueState = this.handleCueState.bind(this)
    this.syncInitialCueState = this.syncInitialCueState.bind(this)
    document.addEventListener("cue-player:state", this.handleCueState)
    document.addEventListener("turbo:load", this.syncInitialCueState)
    this.syncInitialCueState()
  }

  disconnect() {
    if (this.modeValue !== "cue") return

    document.removeEventListener("cue-player:state", this.handleCueState)
    document.removeEventListener("turbo:load", this.syncInitialCueState)
  }

  syncInitialCueState() {
    const cueAudio = document.querySelector('[data-cue-player-target="audio"]')
    if (!cueAudio) return

    this.applyCueState(cueAudio.src, !cueAudio.paused)
  }

  play() {
    document.dispatchEvent(
      new CustomEvent("audio-player:play", { detail: { url: this.urlValue, name: this.nameValue } })
    )
  }

  // Vorhoeren (Intent 51): eigener Kanal, unterbricht die laufende Queue-Wiedergabe im
  // Haupt-Player nicht - siehe cue_player_controller.js. Ist dieser Button gerade der aktive,
  // spielende Vorhoer-Track, beendet ein erneuter Klick das Vorhoeren (pausiert), statt den
  // Track von vorne neu zu starten (Intent 51 Nachtrag).
  cue() {
    if (this.isActiveCueTrack) {
      document.dispatchEvent(new CustomEvent("audio-player:cue-toggle"))
      return
    }

    document.dispatchEvent(
      new CustomEvent("audio-player:cue", { detail: { url: this.urlValue, name: this.nameValue } })
    )
  }

  handleCueState(event) {
    this.applyCueState(event.detail.url, event.detail.playing)
  }

  applyCueState(url, playing) {
    const resolvedUrl = new URL(this.urlValue, window.location.origin).href
    const isActive = url === resolvedUrl && playing
    this.isActiveCueTrack = isActive

    this.element.classList.toggle("btn-danger", isActive)
    this.element.classList.toggle("btn-outline-secondary", !isActive)
    this.element.textContent = isActive ? "⏸" : "🎧"
  }
}
