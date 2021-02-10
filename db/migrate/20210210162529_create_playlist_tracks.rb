class CreatePlaylistTracks < ActiveRecord::Migration[6.1]
  def change
    create_table :playlist_tracks do |t|
      t.references :playlist, null: false, foreign_key: {on_delete: :cascade}
      t.references :track, null: false, foreign_key: {on_delete: :cascade}
      t.datetime :added_at
      t.timestamps
    end
  end
end
