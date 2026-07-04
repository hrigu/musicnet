import { Controller } from "@hotwired/stimulus"

// Einzige Instanz, dauerhaft im Layout (data-turbo-permanent) - ueberlebt Turbo-Drive-Visits.
// Empfaengt "audio-player:play"-Events von den einzelnen Track-Play-Buttons
// (audio_trigger_controller.js). Die Song-Queue selbst lebt seit Intent 42 in der DB statt hier im
// JS - dieser Controller kuemmert sich nur noch um die eigentliche Wiedergabe (Play/Pause/Seek/
// Fortschritt) und fragt beim Trackende bzw. beim Player-eigenen Play-Button per Fetch den
// naechsten Track aus der Queue ab (queue_entries#advance).
export default class extends Controller {
  static targets = ["audio", "icon", "name", "progress", "currentTime", "duration"]

  connect() {
    this.handlePlayEvent = this.handlePlayEvent.bind(this)
    this.handleAudioPlay = () => (this.iconTarget.textContent = "⏸")
    this.handleAudioPause = () => (this.iconTarget.textContent = "▶")
    this.handleAudioEnded = () => this.playNextInQueue()
    this.handleTimeUpdate = () => this.updateProgress()
    this.handleLoadedMetadata = () => this.updateDuration()

    document.addEventListener("audio-player:play", this.handlePlayEvent)

    this.audioTarget.addEventListener("play", this.handleAudioPlay)
    this.audioTarget.addEventListener("pause", this.handleAudioPause)
    this.audioTarget.addEventListener("ended", this.handleAudioEnded)
    this.audioTarget.addEventListener("timeupdate", this.handleTimeUpdate)
    this.audioTarget.addEventListener("loadedmetadata", this.handleLoadedMetadata)
  }

  disconnect() {
    document.removeEventListener("audio-player:play", this.handlePlayEvent)

    this.audioTarget.removeEventListener("play", this.handleAudioPlay)
    this.audioTarget.removeEventListener("pause", this.handleAudioPause)
    this.audioTarget.removeEventListener("ended", this.handleAudioEnded)
    this.audioTarget.removeEventListener("timeupdate", this.handleTimeUpdate)
    this.audioTarget.removeEventListener("loadedmetadata", this.handleLoadedMetadata)
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
}
