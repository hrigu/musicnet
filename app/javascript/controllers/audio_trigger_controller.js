import { Controller } from "@hotwired/stimulus"

// Sitzt auf dem Play-/Vorhoer-Button einer Track-Zeile. Kennt weder den globalen Player noch den
// Cue-Player direkt (die liegen an einer ganz anderen Stelle im DOM) - dispatcht stattdessen ein
// Event auf document, auf das audio_player_controller.js bzw. cue_player_controller.js lauschen
// (Intent 51). Entkoppelt, da Buttons ueberall verstreut sind (Tracks-Tabelle, Playlist-Tracks-
// Tabelle, Track-Detailseite). Das Einreihen in die Queue laeuft seit Intent 42 ueber einen
// normalen button_to-POST-Request statt ueber diesen Controller.
export default class extends Controller {
  static values = { url: String, name: String, mode: { type: String, default: "play" } }

  // Beide Modi zeigen den Live-Zustand (Play seit Intent 62, Cue seit Intent 51 Nachtrag) -
  // gruen+Pause fuer den Hauptkanal, rot+Pause fuer den Vorhoerkanal.
  //
  // Sync auf turbo:load statt (nur) beim Verbinden (Nachtrag): waehrend einer Turbo-Drive-
  // Navigation verbinden sich die neuen Zeilen-Buttons, BEVOR das permanente Player-Element
  // wieder in das neue Dokument eingehaengt ist - ein direkter DOM-Read zum Zeitpunkt von
  // connect() findet das <audio>-Element daher manchmal noch gar nicht (empirisch verifiziert).
  // turbo:load feuert erst, wenn Turbo die Seite inkl. aller permanenten Elemente fertig
  // gerendert hat, und deckt sowohl den allerersten Seitenaufruf als auch jede weitere
  // Drive-Navigation ab.
  connect() {
    this.isActiveCueTrack = false
    this.isActivePlayTrack = false
    this.syncInitialState = this.syncInitialState.bind(this)
    document.addEventListener("turbo:load", this.syncInitialState)

    if (this.modeValue === "cue") {
      this.handleCueState = this.handleCueState.bind(this)
      document.addEventListener("cue-player:state", this.handleCueState)
    } else {
      this.handlePlayState = this.handlePlayState.bind(this)
      document.addEventListener("audio-player:state", this.handlePlayState)
    }

    this.syncInitialState()
  }

  disconnect() {
    document.removeEventListener("turbo:load", this.syncInitialState)

    if (this.modeValue === "cue") {
      document.removeEventListener("cue-player:state", this.handleCueState)
    } else {
      document.removeEventListener("audio-player:state", this.handlePlayState)
    }
  }

  syncInitialState() {
    if (this.modeValue === "cue") {
      const cueAudio = document.querySelector('[data-cue-player-target="audio"]')
      if (!cueAudio) return

      this.applyCueState(cueAudio.src, !cueAudio.paused)
    } else {
      const mainAudio = document.querySelector('[data-audio-player-target="audio"]')
      if (!mainAudio) return

      this.applyPlayState(mainAudio.src, !mainAudio.paused)
    }
  }

  // Schutz vor Fehlmanipulation waehrend einer laufenden Hauptkanal-Wiedergabe (Intent 62) - ein
  // Fehlklick soll den Dancefloor nicht versehentlich stoppen oder umschalten. Direkter, lebender
  // DOM-Read des Hauptkanal-<audio>-Elements statt eines gecachten Werts, damit der Zustand im
  // Klickmoment garantiert aktuell ist.
  play() {
    const mainAudio = document.querySelector('[data-audio-player-target="audio"]')

    if (this.isActivePlayTrack) {
      if (!confirm("Laufende Wiedergabe wirklich pausieren?")) return

      document.dispatchEvent(new CustomEvent("audio-player:toggle"))
      return
    }

    if (mainAudio && !mainAudio.paused) {
      if (!confirm(`Laufenden Song stoppen und "${this.nameValue}" abspielen?`)) return
    }

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

  handlePlayState(event) {
    this.applyPlayState(event.detail.url, event.detail.playing)
  }

  applyCueState(url, playing) {
    const resolvedUrl = new URL(this.urlValue, window.location.origin).href
    const isActive = url === resolvedUrl && playing
    this.isActiveCueTrack = isActive

    this.element.classList.toggle("btn-danger", isActive)
    this.element.classList.toggle("btn-outline-secondary", !isActive)
    this.element.textContent = isActive ? "⏸" : "🎧"
  }

  applyPlayState(url, playing) {
    const resolvedUrl = new URL(this.urlValue, window.location.origin).href
    const isActive = url === resolvedUrl && playing
    this.isActivePlayTrack = isActive

    this.element.classList.toggle("btn-success", isActive)
    this.element.classList.toggle("btn-outline-secondary", !isActive)
    this.element.textContent = isActive ? "⏸" : "▶"
  }
}
