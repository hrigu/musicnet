# frozen_string_literal: true

class AddHiddenTrackColumnsToUsers < ActiveRecord::Migration[8.1]
  def change
    # Liste der Spalten-Keys (siehe Track::OPTIONAL_COLUMNS), die der User in der Tracks-/
    # Playlist-Detailtabelle ausgeblendet hat - leer bedeutet "alle Spalten sichtbar" (Intent 80),
    # damit sich fuer bestehende User ohne diese Einstellung nichts am aktuellen Anblick aendert.
    add_column :users, :hidden_track_columns, :json, default: [], null: false
  end
end
