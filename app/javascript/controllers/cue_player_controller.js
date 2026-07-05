import { Controller } from "@hotwired/stimulus"
import { loadOutputDevices, restoreOutputDevice, applyOutputDevice } from "audio_output_device"

// Zweiter, unabhaengiger Audio-Kanal zum Vorhoeren (Intent 51) - kennt audio_player_controller.js
// nicht (gleiches Entkopplungs-Pattern wie Trigger-Button/Haupt-Player), damit ein Vorhoeren die
// laufende Queue-Wiedergabe im Haupt-Player nie unterbricht. Kann per setSinkId() auf ein anderes
// Ausgabegeraet (z.B. Kopfhoerer) geroutet werden - der Haupt-Player hat seine eigene, unabhaengige
// Geraete-Auswahl (audio_player_controller.js), beide teilen sich die Logik in
// audio_output_device.js. Ohne eigene Auswahl wuerde der Haupt-Player einfach dem
// System-Standardgeraet folgen - verbindet man Bluetooth-Kopfhoerer, wird das oft automatisch das
// neue Standardgeraet, und ohne Pinning wuerden beide Kanaele dort landen (Nachtrag Intent 51).
const SINK_ID_STORAGE_KEY = "musicnet:cuePlayerSinkId"

export default class extends Controller {
  static targets = ["audio", "icon", "name", "deviceSelect", "chooseButton", "toggleButton"]

  connect() {
    this.handleCueEvent = this.handleCueEvent.bind(this)
    this.handleToggleEvent = this.toggle.bind(this)
    this.broadcastState = this.broadcastState.bind(this)
    document.addEventListener("audio-player:cue", this.handleCueEvent)
    document.addEventListener("audio-player:cue-toggle", this.handleToggleEvent)

    this.audioTarget.addEventListener("play", () => {
      this.iconTarget.textContent = "⏸"
      this.toggleButtonTarget.classList.add("btn-danger")
      this.toggleButtonTarget.classList.remove("btn-outline-secondary")
      this.broadcastState()
    })
    this.audioTarget.addEventListener("pause", () => {
      this.iconTarget.textContent = "▶"
      this.toggleButtonTarget.classList.remove("btn-danger")
      this.toggleButtonTarget.classList.add("btn-outline-secondary")
      this.broadcastState()
    })

    restoreOutputDevice(this.audioTarget, SINK_ID_STORAGE_KEY)
  }

  disconnect() {
    document.removeEventListener("audio-player:cue", this.handleCueEvent)
    document.removeEventListener("audio-player:cue-toggle", this.handleToggleEvent)
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

  // Informiert die Vorhoer-Buttons in den Track-Zeilen (audio_trigger_controller.js) darueber,
  // welcher Track gerade im Cue-Kanal spielt, damit sich genau dieser Button rot faerben kann
  // (Intent 51 Nachtrag).
  broadcastState() {
    document.dispatchEvent(
      new CustomEvent("cue-player:state", {
        detail: { url: this.audioTarget.src, playing: !this.audioTarget.paused },
      })
    )
  }

  // Nicht automatisiert testbar (die getUserMedia-Berechtigungsabfrage hat kein DOM) - siehe
  // Intent 51.
  async chooseOutputDevice() {
    if (!this.audioTarget.setSinkId) {
      alert("Dieser Browser unterstützt keine Ausgabegerät-Auswahl für den Vorhör-Kanal.")
      return
    }

    const outputs = await loadOutputDevices()
    if (outputs.length === 0) return

    this.deviceSelectTarget.innerHTML = outputs
      .map((device, index) => `<option value="${device.deviceId}">${device.label || `Gerät ${index + 1}`}</option>`)
      .join("")
    this.deviceSelectTarget.classList.remove("d-none")
    this.chooseButtonTarget.classList.add("d-none")
  }

  selectOutputDevice() {
    applyOutputDevice(this.audioTarget, this.deviceSelectTarget.value, SINK_ID_STORAGE_KEY)
  }
}
