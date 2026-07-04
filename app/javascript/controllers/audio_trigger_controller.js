import { Controller } from "@hotwired/stimulus"

// Sitzt auf Play-/Queue-Button einer Track-Zeile. Kennt den globalen Player nicht direkt (der
// liegt an einer ganz anderen Stelle im DOM) - dispatcht stattdessen Events auf document, auf die
// audio_player_controller.js lauscht. Entkoppelt, da Buttons ueberall verstreut sind (Tracks-
// Tabelle, Playlist-Tracks-Tabelle, Track-Detailseite).
export default class extends Controller {
  static values = { url: String, name: String }

  play() {
    document.dispatchEvent(
      new CustomEvent("audio-player:play", { detail: { url: this.urlValue, name: this.nameValue } })
    )
  }

  enqueue() {
    document.dispatchEvent(
      new CustomEvent("audio-player:enqueue", { detail: { url: this.urlValue, name: this.nameValue } })
    )
  }
}
