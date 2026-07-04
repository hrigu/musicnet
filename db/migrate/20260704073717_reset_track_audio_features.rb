# frozen_string_literal: true

# Setzt audio_features fuer alle Tracks auf NULL zurueck. Bisher stand dort fuer jeden
# Track der Literalwert "null" (nil.to_json auf eine bereits als t.json typisierte Spalte
# geschrieben - ein Doppel-Encoding-Bug, kein echtes Ergebnis), Track#af las das als
# String statt als Hash. Voraussetzung fuer die Essentia-Umstellung (Intent 35), die
# audio_features als Hash schreibt.
class ResetTrackAudioFeatures < ActiveRecord::Migration[7.1]
  def up
    execute "UPDATE tracks SET audio_features = NULL"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
