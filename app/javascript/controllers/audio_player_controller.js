import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["audio", "icon"]

  toggle() {
    if (this.audioTarget.paused) {
      this.audioTarget.play()
    } else {
      this.audioTarget.pause()
    }
  }

  connect() {
    this.audioTarget.addEventListener("play", () => (this.iconTarget.textContent = "⏸"))
    this.audioTarget.addEventListener("pause", () => (this.iconTarget.textContent = "▶"))
    this.audioTarget.addEventListener("ended", () => (this.iconTarget.textContent = "▶"))
  }
}
