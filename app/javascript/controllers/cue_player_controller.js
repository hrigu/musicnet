import { Controller } from "@hotwired/stimulus"

// Zweiter, unabhaengiger Audio-Kanal zum Vorhoeren (Intent 51) - kennt audio_player_controller.js
// nicht (gleiches Entkopplungs-Pattern wie Trigger-Button/Haupt-Player), damit ein Vorhoeren die
// laufende Queue-Wiedergabe im Haupt-Player nie unterbricht. Kann per setSinkId() auf ein anderes
// Ausgabegeraet (z.B. Kopfhoerer) geroutet werden, waehrend der Haupt-Player auf dem
// Standard-Ausgabegeraet bleibt.
const SINK_ID_STORAGE_KEY = "musicnet:cuePlayerSinkId"

export default class extends Controller {
  static targets = ["audio", "icon", "name"]

  connect() {
    this.handleCueEvent = this.handleCueEvent.bind(this)
    document.addEventListener("audio-player:cue", this.handleCueEvent)

    this.audioTarget.addEventListener("play", () => (this.iconTarget.textContent = "⏸"))
    this.audioTarget.addEventListener("pause", () => (this.iconTarget.textContent = "▶"))

    this.restoreOutputDevice()
  }

  disconnect() {
    document.removeEventListener("audio-player:cue", this.handleCueEvent)
  }

  handleCueEvent(event) {
    const { url, name } = event.detail
    this.audioTarget.src = url
    this.nameTarget.textContent = name
    this.audioTarget.play()
  }

  toggle() {
    if (this.audioTarget.paused) {
      this.audioTarget.play()
    } else {
      this.audioTarget.pause()
    }
  }

  // Oeffnet den nativen Geraete-Dialog des Browsers (transient user activation noetig, darum nur
  // aus diesem Klick-Handler aufrufbar). Nicht automatisiert testbar (kein DOM, Browser-Chrome-UI)
  // - siehe Intent 51.
  async chooseOutputDevice() {
    if (!navigator.mediaDevices?.selectAudioOutput) {
      alert("Dieser Browser unterstützt keine Ausgabegerät-Auswahl für den Vorhör-Kanal.")
      return
    }

    try {
      const device = await navigator.mediaDevices.selectAudioOutput()
      await this.audioTarget.setSinkId(device.deviceId)
      localStorage.setItem(SINK_ID_STORAGE_KEY, device.deviceId)
    } catch {
      // Nutzer hat den Geraete-Dialog abgebrochen - kein Fehlerzustand.
    }
  }

  // Geraete-IDs sind nicht ueber alle Sessions/Neustarts hinweg garantiert stabil - ein
  // Fehlschlag hier bedeutet nur, dass das Geraet nicht mehr verfuegbar ist, kein Fehlerzustand.
  restoreOutputDevice() {
    const sinkId = localStorage.getItem(SINK_ID_STORAGE_KEY)
    if (!sinkId || !this.audioTarget.setSinkId) return

    this.audioTarget.setSinkId(sinkId).catch(() => {})
  }
}
