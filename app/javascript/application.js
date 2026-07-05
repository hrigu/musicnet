

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
