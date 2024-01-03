class DownloadTrackService

  def initialize tracks
    @tracks = tracks
  end

  # lädt die Songs der @playlist runter und speichert sie unter downloads/tracks.
  # Tracks die schon vorhanden sind werden nicht nochmals runtergeladen

  def download
    tracks_dir = Rails.root.join(DownloadPlaylistService::TRACKS_DIR)
    Rails.logger.info "DownloadTrackService#download: current_dir = #{tracks_dir}"
    Dir.chdir tracks_dir
    result = system( build_command )
    Rails.logger.info(result)

  end

  private

  def build_command
    o = {
      format: '--format m4a'
    }

    track_urls = @tracks.map{ |t| "https://open.spotify.com/track/#{t.spotify_id}"}

    cmd = "spotdl download #{track_urls.join(' ')} #{o[:format]}"
    Rails.logger.info cmd
    cmd
  end



end
