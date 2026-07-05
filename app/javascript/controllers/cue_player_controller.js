import { Controller } from "@hotwired/stimulus"

// Zweiter, unabhaengiger Audio-Kanal zum Vorhoeren (Intent 51) - kennt audio_player_controller.js
// nicht (gleiches Entkopplungs-Pattern wie Trigger-Button/Haupt-Player), damit ein Vorhoeren die
// laufende Queue-Wiedergabe im Haupt-Player nie unterbricht. Kann per setSinkId() auf ein anderes
// Ausgabegeraet (z.B. Kopfhoerer) geroutet werden, waehrend der Haupt-Player auf dem
// Standard-Ausgabegeraet bleibt.
const SINK_ID_STORAGE_KEY = "musicnet:cuePlayerSinkId"

export default class extends Controller {
  static targets = ["audio", "icon", "name", "deviceSelect", "chooseButton"]

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

  // navigator.mediaDevices.selectAudioOutput() (nativer Geraete-Dialog) ist in Chrome nicht
  // implementiert (nur Firefox 116+, siehe MDN Browser-Compat-Data) - Chrome kennt nur den
  // aelteren enumerateDevices()-Weg mit eigenem Dropdown. Chrome zeigt dabei Geraete-Labels
  // (auch fuer audiooutput) grundsaetzlich erst nach einer erteilten getUserMedia-Berechtigung
  // (Plattform-Einschraenkung, betrifft nicht nur Mikrofon-Input) - der Stream wird sofort
  // wieder gestoppt, nur die Berechtigung wird gebraucht. Nicht automatisiert testbar (echter
  // Berechtigungs-Dialog hat kein DOM) - siehe Intent 51.
  async chooseOutputDevice() {
    if (!this.audioTarget.setSinkId) {
      alert("Dieser Browser unterstützt keine Ausgabegerät-Auswahl für den Vorhör-Kanal.")
      return
    }

    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true })
      stream.getTracks().forEach((track) => track.stop())
    } catch {
      // Berechtigung verweigert oder Dialog abgebrochen - kein Fehlerzustand.
      return
    }

    const devices = await navigator.mediaDevices.enumerateDevices()
    const outputs = devices.filter((device) => device.kind === "audiooutput")
    if (outputs.length === 0) return

    this.deviceSelectTarget.innerHTML = outputs
      .map((device, index) => `<option value="${device.deviceId}">${device.label || `Gerät ${index + 1}`}</option>`)
      .join("")
    this.deviceSelectTarget.classList.remove("d-none")
    this.chooseButtonTarget.classList.add("d-none")
  }

  async selectOutputDevice() {
    const deviceId = this.deviceSelectTarget.value
    await this.audioTarget.setSinkId(deviceId)
    localStorage.setItem(SINK_ID_STORAGE_KEY, deviceId)
  }

  // Geraete-IDs sind nicht ueber alle Sessions/Neustarts hinweg garantiert stabil - ein
  // Fehlschlag hier bedeutet nur, dass das Geraet nicht mehr verfuegbar ist, kein Fehlerzustand.
  restoreOutputDevice() {
    const sinkId = localStorage.getItem(SINK_ID_STORAGE_KEY)
    if (!sinkId || !this.audioTarget.setSinkId) return

    this.audioTarget.setSinkId(sinkId).catch(() => {})
  }
}
