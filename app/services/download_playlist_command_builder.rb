# frozen_string_literal: true

class DownloadPlaylistCommandBuilder
  def initialize(playlist)
    @playlist = playlist
  end

  def build
    "spotdl sync #{playlist_url} --save-file #{save_file} --sync-without-deleting --user-auth --format m4a"
  end

  private

  def playlist_url
    @playlist.url || "https://open.spotify.com/playlist/#{@playlist.spotify_id}"
  end

  def save_file
    "#{@playlist.name_path_ready}.spotdl"
  end
end
