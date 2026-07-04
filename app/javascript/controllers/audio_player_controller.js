import { Controller } from "@hotwired/stimulus"

const MAX_QUEUE_SIZE = 5

// Einzige Instanz, dauerhaft im Layout (data-turbo-permanent) - der DOM-Knoten selbst ueberlebt
// Turbo-Drive-Visits. Stimulus' eigener Connect/Disconnect-Zyklus fuer diesen Knoten tut das aber
// NICHT immer mit: ein Link mit data-turbo-frame="_top", der aus einem aktiven turbo_frame_tag
// ausbricht (z.B. die Artist-/Tracknamen-Links in tracks/_track.erb), loest bei Turbo einen
// anderen internen Ablauf aus als ein gewoehnlicher Top-Level-Link-Klick und verbindet diesen
// Controller dabei neu - ein zweites Mal "connect()" auf demselben Element. Deshalb lebt die
// Queue nicht in einer Instanzvariable (die waere nach so einem Reconnect weg), sondern direkt
// auf dem Element selbst, das nachweislich immer derselbe Knoten bleibt. Aus demselben Grund
// werden alle Event-Listener ueber benannte, gebundene Methoden registriert, damit disconnect()
// sie bei einem Reconnect sauber entfernen kann statt sie zu duplizieren.
export default class extends Controller {
  static targets = ["audio", "icon", "name", "progress", "currentTime", "duration", "queue"]

  connect() {
    this.element.audioPlayerQueueEntries ??= []

    this.handlePlayEvent = this.handlePlayEvent.bind(this)
    this.handleEnqueueEvent = this.handleEnqueueEvent.bind(this)
    this.handleAudioPlay = () => (this.iconTarget.textContent = "⏸")
    this.handleAudioPause = () => (this.iconTarget.textContent = "▶")
    this.handleAudioEnded = () => this.playNextInQueue()
    this.handleTimeUpdate = () => this.updateProgress()
    this.handleLoadedMetadata = () => this.updateDuration()

    document.addEventListener("audio-player:play", this.handlePlayEvent)
    document.addEventListener("audio-player:enqueue", this.handleEnqueueEvent)

    this.audioTarget.addEventListener("play", this.handleAudioPlay)
    this.audioTarget.addEventListener("pause", this.handleAudioPause)
    this.audioTarget.addEventListener("ended", this.handleAudioEnded)
    this.audioTarget.addEventListener("timeupdate", this.handleTimeUpdate)
    this.audioTarget.addEventListener("loadedmetadata", this.handleLoadedMetadata)
  }

  disconnect() {
    document.removeEventListener("audio-player:play", this.handlePlayEvent)
    document.removeEventListener("audio-player:enqueue", this.handleEnqueueEvent)

    this.audioTarget.removeEventListener("play", this.handleAudioPlay)
    this.audioTarget.removeEventListener("pause", this.handleAudioPause)
    this.audioTarget.removeEventListener("ended", this.handleAudioEnded)
    this.audioTarget.removeEventListener("timeupdate", this.handleTimeUpdate)
    this.audioTarget.removeEventListener("loadedmetadata", this.handleLoadedMetadata)
  }

  get queueEntries() {
    return this.element.audioPlayerQueueEntries
  }

  handlePlayEvent(event) {
    this.play(event.detail)
  }

  handleEnqueueEvent(event) {
    if (this.queueEntries.length >= MAX_QUEUE_SIZE) return

    this.queueEntries.push(event.detail)
    this.renderQueue()
  }

  removeFromQueue(event) {
    this.queueEntries.splice(event.params.index, 1)
    this.renderQueue()
  }

  playNextInQueue() {
    this.iconTarget.textContent = "▶"
    if (this.queueEntries.length === 0) return

    const next = this.queueEntries.shift()
    this.renderQueue()
    this.play(next)
  }

  play({ url, name }) {
    this.audioTarget.src = url
    this.nameTarget.textContent = name
    this.audioTarget.play()
  }

  // Zeigt die Queue absichtlich umgekehrt zur internen Reihenfolge an: der als naechstes
  // gespielte Track (queueEntries[0], siehe playNextInQueue) steht zuunterst, neu hinzugefuegte
  // erscheinen zuoberst. Der Index im Entfernen-Button bezieht sich weiterhin auf die
  // tatsaechliche Position im internen Array, nicht auf die Anzeigeposition.
  renderQueue() {
    if (this.queueEntries.length === 0) {
      this.queueTarget.textContent = "Queue leer"
      return
    }

    this.queueTarget.innerHTML = this.queueEntries
      .map((entry, index) => ({ entry, index }))
      .reverse()
      .map(
        ({ entry, index }) => `
          <div class="queue-entry d-flex align-items-center gap-2">
            <span class="text-truncate">${entry.name}</span>
            <button type="button" class="btn btn-sm btn-link p-0"
                    data-action="audio-player#removeFromQueue" data-audio-player-index-param="${index}">×</button>
          </div>
        `
      )
      .join("")
  }

  // Ohne jemals geladenen Track (frischer Player, leere src) oder nach einem zu Ende gespielten
  // Track wuerde audioTarget.play() ohne Wirkung bleiben bzw. nur den alten Track neu starten -
  // in beiden Faellen soll stattdessen die Queue weiterlaufen, falls sie etwas enthaelt.
  toggle() {
    if ((!this.audioTarget.src || this.audioTarget.ended) && this.queueEntries.length > 0) {
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
