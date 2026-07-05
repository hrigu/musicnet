import { Controller } from "@hotwired/stimulus"
import { loadOutputDevices, restoreOutputDevice, applyOutputDevice } from "audio_output_device"

// Einzige Instanz, dauerhaft im Layout (data-turbo-permanent) - ueberlebt Turbo-Drive-Visits.
// Empfaengt "audio-player:play"-Events von den einzelnen Track-Play-Buttons
// (audio_trigger_controller.js). Die Song-Queue selbst lebt seit Intent 42 in der DB statt hier im
// JS - dieser Controller kuemmert sich nur noch um die eigentliche Wiedergabe (Play/Pause/Seek/
// Fortschritt) und fragt beim Trackende bzw. beim Player-eigenen Play-Button per Fetch den
// naechsten Track aus der Queue ab (queue_entries#advance).
// Eigene Ausgabegeraet-Auswahl (Nachtrag Intent 51): ohne sie folgt dieser Player einfach dem
// System-Standardgeraet - verbindet man Bluetooth-Kopfhoerer, wird das oft automatisch das neue
// Standardgeraet, und der Haupt-Kanal (Dancefloor/Lautsprecher) wuerde ungewollt mitwandern.
const SINK_ID_STORAGE_KEY = "musicnet:mainPlayerSinkId"

export default class extends Controller {
  static targets = [
    "audio", "icon", "name", "progress", "currentTime", "duration", "deviceSelect", "chooseButton",
  ]

  connect() {
    console.log("[audio-diagnostic]", {
      channel: "main", lifecycle: "connect", timestamp: new Date().toISOString(),
    })
    this.handlePlayEvent = this.handlePlayEvent.bind(this)
    this.handleAudioPlay = () => (this.iconTarget.textContent = "⏸")
    this.handleAudioPause = () => (this.iconTarget.textContent = "▶")
    this.handleAudioEnded = () => this.playNextInQueue()
    this.handleTimeUpdate = () => this.updateProgress()
    this.handleLoadedMetadata = () => this.updateDuration()
    // Diagnose fuer einen sporadischen, nicht reproduzierbaren Audio-Aussetzer (Intent 56) -
    // wieder entfernen/reduzieren, sobald die Ursache gefunden ist.
    this.handleDiagnosticEvent = (event) => this.logDiagnostic(event)

    document.addEventListener("audio-player:play", this.handlePlayEvent)

    this.audioTarget.addEventListener("play", this.handleAudioPlay)
    this.audioTarget.addEventListener("pause", this.handleAudioPause)
    this.audioTarget.addEventListener("ended", this.handleAudioEnded)
    this.audioTarget.addEventListener("timeupdate", this.handleTimeUpdate)
    this.audioTarget.addEventListener("loadedmetadata", this.handleLoadedMetadata)
    ;["pause", "error", "stalled", "emptied", "abort"].forEach((type) =>
      this.audioTarget.addEventListener(type, this.handleDiagnosticEvent)
    )

    restoreOutputDevice(this.audioTarget, SINK_ID_STORAGE_KEY)
  }

  disconnect() {
    console.log("[audio-diagnostic]", {
      channel: "main", lifecycle: "disconnect", timestamp: new Date().toISOString(),
    })
    document.removeEventListener("audio-player:play", this.handlePlayEvent)

    this.audioTarget.removeEventListener("play", this.handleAudioPlay)
    this.audioTarget.removeEventListener("pause", this.handleAudioPause)
    this.audioTarget.removeEventListener("ended", this.handleAudioEnded)
    ;["pause", "error", "stalled", "emptied", "abort"].forEach((type) =>
      this.audioTarget.removeEventListener(type, this.handleDiagnosticEvent)
    )
    this.audioTarget.removeEventListener("timeupdate", this.handleTimeUpdate)
    this.audioTarget.removeEventListener("loadedmetadata", this.handleLoadedMetadata)
  }

  // Intent 56: Diagnose fuer einen sporadischen, bisher nicht reproduzierbaren Audio-Aussetzer.
  logDiagnostic(event) {
    console.log("[audio-diagnostic]", {
      channel: "main",
      type: event.type,
      src: this.audioTarget.src,
      currentTime: this.audioTarget.currentTime,
      timestamp: new Date().toISOString(),
    })
  }

  handlePlayEvent(event) {
    this.play(event.detail)
  }

  async playNextInQueue() {
    this.iconTarget.textContent = "▶"

    const response = await fetch("/queue_entries/advance", {
      method: "POST",
      headers: {
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content,
        Accept: "application/json",
      },
    })
    if (response.status === 204) return

    this.play(await response.json())
  }

  play({ url, name }) {
    this.audioTarget.src = url
    this.nameTarget.textContent = name
    this.audioTarget.play()
  }

  // Ohne jemals geladenen Track (frischer Player, leere src) oder nach einem zu Ende gespielten
  // Track wuerde audioTarget.play() ohne Wirkung bleiben bzw. nur den alten Track neu starten -
  // in beiden Faellen soll stattdessen die Queue weiterlaufen, falls der Server einen Track liefert.
  toggle() {
    if (!this.audioTarget.src || this.audioTarget.ended) {
      this.playNextInQueue()
      return
    }

    if (this.audioTarget.paused) {
      this.audioTarget.play()
    } else {
      this.audioTarget.pause()
    }
  }

  seek() {
    this.audioTarget.currentTime = this.progressTarget.value
  }

  updateProgress() {
    this.progressTarget.value = this.audioTarget.currentTime
    this.currentTimeTarget.textContent = this.formatTime(this.audioTarget.currentTime)
  }

  updateDuration() {
    this.progressTarget.max = this.audioTarget.duration
    this.durationTarget.textContent = this.formatTime(this.audioTarget.duration)
  }

  formatTime(seconds) {
    if (!isFinite(seconds)) return "0:00"

    const minutes = Math.floor(seconds / 60)
    const remainingSeconds = Math.floor(seconds % 60).toString().padStart(2, "0")
    return `${minutes}:${remainingSeconds}`
  }

  // Nicht automatisiert testbar (die getUserMedia-Berechtigungsabfrage hat kein DOM) - siehe
  // Intent 51.
  async chooseOutputDevice() {
    if (!this.audioTarget.setSinkId) {
      alert("Dieser Browser unterstützt keine Ausgabegerät-Auswahl für den Haupt-Player.")
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
