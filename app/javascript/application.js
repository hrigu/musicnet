

// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails

import "popper"
import "bootstrap"
import "@hotwired/turbo-rails"
import "controllers"

// Diagnose fuer einen sporadischen, bisher nicht reproduzierbaren Audio-Aussetzer bei
// Seitenwechseln (Intent 56) - unabhaengig vom Stimulus-Controller-Lifecycle registriert, damit
// ein moeglicherweise unerwartetes Verhalten der Turbo-Permanent-Elemente selbst sichtbar wird.
// Wieder entfernen/reduzieren, sobald die Ursache gefunden ist.
function logTurboAudioDiagnostic(phase) {
  const main = document.querySelector('[data-audio-player-target="audio"]')
  const cue = document.querySelector('[data-cue-player-target="audio"]')
  console.log("[audio-diagnostic]", {
    lifecycle: "turbo",
    phase,
    main: main && { src: main.src, paused: main.paused, currentTime: main.currentTime },
    cue: cue && { src: cue.src, paused: cue.paused, currentTime: cue.currentTime },
    timestamp: new Date().toISOString(),
  })
}

;["turbo:before-cache", "turbo:before-render", "turbo:render", "turbo:load"].forEach((eventName) =>
  document.addEventListener(eventName, () => logTurboAudioDiagnostic(eventName))
)

// Nachtrag: ein real beobachteter Aussetzer endete im Log abrupt bei einem blossen "pause" auf dem
// Hauptkanal, OHNE dass danach irgendein turbo:*-Lifecycle-Event mehr auftrat und OHNE sichtbaren
// JS-Fehler in der Konsole - beides deutete bisher auf einen kompletten Seiten-Reload (statt einer
// Turbo-Navigation) oder einen stillen Fehler hin, den das bisherige Logging nicht erfasst.
// pagehide unterscheidet das beim naechsten Mal zweifelsfrei: persisted=false + kein weiteres
// turbo:*-Log danach bestaetigt einen echten Reload/Tab-Wechsel. window.onerror/unhandledrejection
// fangen Fehler ab, die in der Konsole leicht uebersehen werden.
window.addEventListener("pagehide", (event) => {
  console.log("[audio-diagnostic]", {
    lifecycle: "window",
    phase: "pagehide",
    persisted: event.persisted,
    timestamp: new Date().toISOString(),
  })
})

window.addEventListener("error", (event) => {
  console.log("[audio-diagnostic]", {
    lifecycle: "error",
    message: event.message,
    filename: event.filename,
    lineno: event.lineno,
    timestamp: new Date().toISOString(),
  })
})

window.addEventListener("unhandledrejection", (event) => {
  console.log("[audio-diagnostic]", {
    lifecycle: "unhandledrejection",
    reason: String(event.reason),
    timestamp: new Date().toISOString(),
  })
})
