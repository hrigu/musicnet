class CreatePlaylistTracks < ActiveRecord::Migration[6.1]
  def change
    create_table :playlist_tracks do |t|
      t.references :playlist, null: false, foreign_key: {on_delete: :cascade}
      t.references :track, null: false, foreign_key: {on_delete: :cascade}
      t.datetime :added_at
      t.timestamps
    end

    # create_join_table :tracks, :playlists do |t|
    #   t.index :track_id
    #   t.index :playlist_id
    # end

  end
end
