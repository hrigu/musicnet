import { Controller } from "@hotwired/stimulus"

// Sitzt auf dem Play-/Vorhoer-Button einer Track-Zeile. Kennt weder den globalen Player noch den
// Cue-Player direkt (die liegen an einer ganz anderen Stelle im DOM) - dispatcht stattdessen ein
// Event auf document, auf das audio_player_controller.js bzw. cue_player_controller.js lauschen
// (Intent 51). Entkoppelt, da Buttons ueberall verstreut sind (Tracks-Tabelle, Playlist-Tracks-
// Tabelle, Track-Detailseite). Das Einreihen in die Queue laeuft seit Intent 42 ueber einen
// normalen button_to-POST-Request statt ueber diesen Controller.
export default class extends Controller {
  static values = { url: String, name: String }

  play() {
    document.dispatchEvent(
      new CustomEvent("audio-player:play", { detail: { url: this.urlValue, name: this.nameValue } })
    )
  }

  // Vorhoeren (Intent 51): eigener Kanal, unterbricht die laufende Queue-Wiedergabe im
  // Haupt-Player nicht - siehe cue_player_controller.js.
  cue() {
    document.dispatchEvent(
      new CustomEvent("audio-player:cue", { detail: { url: this.urlValue, name: this.nameValue } })
    )
  }
}
