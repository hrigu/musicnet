class CreateTracks < ActiveRecord::Migration[6.1]
  def change
    create_table :tracks do |t|
      t.string :spotify_id
      t.string :name
      t.string :url
      t.integer :duration_ms
      t.integer :popularity
      t.json :audio_features
      # Track löschen wenn Albumg gelöscht wird
      t.references :album, null: false, foreign_key: {on_delete: :cascade}
      t.timestamps
    end
  end
end
