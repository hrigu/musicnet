class DownloadTrackService

  def initialize tracks
    @tracks = tracks
  end

  # Lädt die fehlenden Audiodateien der @tracks herunter - playlist-weise über
  # spotdl sync, damit die Spotify-API gebündelt statt pro Track abgefragt wird
  # (einzelne Track-URLs führten ins Rate-Limit, siehe Intent 21).
  def download
    affected_playlists.each do |playlist|
      DownloadPlaylistService.new(playlist).download
    end
  end

  private

  def affected_playlists
    @tracks.flat_map(&:playlists).uniq
  end

end
