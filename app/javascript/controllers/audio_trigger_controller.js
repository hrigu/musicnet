import { Controller } from "@hotwired/stimulus"

// Sitzt auf dem Play-Button einer Track-Zeile. Kennt den globalen Player nicht direkt (der liegt
// an einer ganz anderen Stelle im DOM) - dispatcht stattdessen ein Event auf document, auf das
// audio_player_controller.js lauscht. Entkoppelt, da Buttons ueberall verstreut sind (Tracks-
// Tabelle, Playlist-Tracks-Tabelle, Track-Detailseite). Das Einreihen in die Queue laeuft seit
// Intent 42 ueber einen normalen button_to-POST-Request statt ueber diesen Controller.
export default class extends Controller {
  static values = { url: String, name: String }

  play() {
    document.dispatchEvent(
      new CustomEvent("audio-player:play", { detail: { url: this.urlValue, name: this.nameValue } })
    )
  }
}
