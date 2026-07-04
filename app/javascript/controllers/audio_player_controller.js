import { Controller } from "@hotwired/stimulus"

// Einzige Instanz, dauerhaft im Layout (data-turbo-permanent) - ueberlebt Turbo-Drive-Visits.
// Empfaengt "audio-player:play"-Events von den einzelnen Track-Play-Buttons (audio_trigger_controller.js).
export default class extends Controller {
  static targets = ["audio", "icon", "name", "progress", "currentTime", "duration"]

  connect() {
    this.handlePlayEvent = this.handlePlayEvent.bind(this)
    document.addEventListener("audio-player:play", this.handlePlayEvent)

    this.audioTarget.addEventListener("play", () => (this.iconTarget.textContent = "⏸"))
    this.audioTarget.addEventListener("pause", () => (this.iconTarget.textContent = "▶"))
    this.audioTarget.addEventListener("ended", () => (this.iconTarget.textContent = "▶"))
    this.audioTarget.addEventListener("timeupdate", () => this.updateProgress())
    this.audioTarget.addEventListener("loadedmetadata", () => this.updateDuration())
  }

  disconnect() {
    document.removeEventListener("audio-player:play", this.handlePlayEvent)
  }

  handlePlayEvent(event) {
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
}
