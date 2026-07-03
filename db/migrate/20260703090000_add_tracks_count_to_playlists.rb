class AddTracksCountToPlaylists < ActiveRecord::Migration[8.1]
  def up
    add_column :playlists, :tracks_count, :integer, null: false, default: 0

    Playlist.reset_column_information
    Playlist.find_each do |playlist|
      Playlist.reset_counters(playlist.id, :playlist_tracks)
    end
  end

  def down
    remove_column :playlists, :tracks_count
  end
end
