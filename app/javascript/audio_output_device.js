// Gemeinsame Ausgabegeraet-Auswahl fuer Haupt- und Cue-Player (Intent 51 Nachtrag). Chrome
// unterstuetzt navigator.mediaDevices.selectAudioOutput() nicht (nur Firefox 116+, siehe MDN
// Browser-Compat-Data), daher der aeltere Weg: enumerateDevices() + eigenes <select>. Chrome
// zeigt audiooutput-Labels erst nach einer kurzen getUserMedia-Berechtigung (Plattform-Eigenart,
// kein Bug) - der Stream wird sofort wieder gestoppt, nur die Berechtigung wird gebraucht.
export async function loadOutputDevices() {
  try {
    const stream = await navigator.mediaDevices.getUserMedia({ audio: true })
    stream.getTracks().forEach((track) => track.stop())
  } catch {
    // Berechtigung verweigert oder Dialog abgebrochen - kein Fehlerzustand.
    return []
  }

  const devices = await navigator.mediaDevices.enumerateDevices()
  return devices.filter((device) => device.kind === "audiooutput")
}

// Geraete-IDs sind nicht ueber alle Sessions/Neustarts hinweg garantiert stabil - ein
// Fehlschlag hier bedeutet nur, dass das Geraet nicht mehr verfuegbar ist, kein Fehlerzustand.
// labelElement zeigt den zuletzt gewaehlten Geraetenamen sofort an (Intent 68) - das Label liegt
// bereits in localStorage, ein erneuter enumerateDevices()-Aufruf (mit erneuter
// getUserMedia-Berechtigungsabfrage) ist dafuer nicht noetig.
export function restoreOutputDevice(audioElement, storageKey, labelElement) {
  const sinkId = localStorage.getItem(storageKey)
  if (!sinkId) return

  if (labelElement) labelElement.textContent = localStorage.getItem(`${storageKey}:label`) || ""

  if (!audioElement.setSinkId) return

  audioElement.setSinkId(sinkId).catch(() => {})
}

export async function applyOutputDevice(audioElement, deviceId, deviceLabel, storageKey, labelElement) {
  await audioElement.setSinkId(deviceId)
  localStorage.setItem(storageKey, deviceId)
  localStorage.setItem(`${storageKey}:label`, deviceLabel)
  if (labelElement) labelElement.textContent = deviceLabel
}
