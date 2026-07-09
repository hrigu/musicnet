import { Controller } from "@hotwired/stimulus"

// Inline-Editieren der TrackTag-Staerke direkt in der Tracks-Tabelle (Intent 81). Klick aufs
// Badge blendet das Zahlenfeld ein (nativer Spinner = das vom DJ gewuenschte "Raedchen"); der
// eigentliche Speichervorgang ist ein ganz normaler Turbo-Formular-Submit auf Enter, keine
// eigene Fetch-Logik noetig - die Turbo-Stream-Antwort ersetzt den ganzen Wrapper und damit auch
// automatisch wieder mit der Badge-Ansicht (oder, bei einem Validierungsfehler, erneut mit dem
// Formular inkl. Fehlermeldung, siehe track_tags/update.turbo_stream.erb).
export default class extends Controller {
  static targets = ["badge", "form", "input"]

  edit() {
    this.badgeTarget.classList.add("d-none")
    this.formTarget.classList.remove("d-none")
    this.inputTarget.focus()
    this.inputTarget.select()
  }

  cancel() {
    this.formTarget.classList.add("d-none")
    this.badgeTarget.classList.remove("d-none")
  }

  // Der "×"-Entfernen-Button (Intent 89) sitzt innerhalb des Badge-Spans, dessen eigener
  // click-Handler (edit()) sonst mitausgeloest wuerde (Event-Bubbling) - der Klick soll nur
  // entfernen, nicht zusaetzlich den Staerke-Editor aufklappen.
  stopPropagation(event) {
    event.stopPropagation()
  }

  // Ein Klick, der weder das eigene Badge noch das eigene Formular trifft, bricht den
  // Editiermodus ab - das deckt sowohl "Klick irgendwo daneben" als auch "Klick auf ein anderes
  // Tag" ab, ohne die beiden Faelle getrennt behandeln zu muessen: der Klick auf ein anderes Tag
  // ist aus Sicht *dieses* Controllers ebenfalls einfach ein Klick ausserhalb seines eigenen
  // Elements. Der Fensterweite Listener sitzt auf dem Wrapper-Element selbst (siehe
  // components/_track_tag_badge.erb), nicht nur auf Badge/Formular, damit auch ein Klick auf
  // z.B. die Fehlermeldung darunter nicht faelschlich als "ausserhalb" zaehlt.
  outsideClick(event) {
    if (this.formTarget.classList.contains("d-none")) return
    if (this.element.contains(event.target)) return

    this.cancel()
  }
}
