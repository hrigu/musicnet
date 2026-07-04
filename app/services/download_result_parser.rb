# frozen_string_literal: true

require "json"
require "uri"

# Wertet das Ergebnis eines spotdl-Downloads aus, ohne die Terminal-Ausgabe zu parsen. Erfolg wird
# an der tatsaechlichen Datei entschieden (Track#track_path, frisch nach dem Download geprueft) -
# NICHT an der --save-file-JSON download_url: die ist bei einem echten Fehlschlag genauso null wie
# wenn spotdl die Datei als "already exists" uebersprungen hat (z. B. weil sie in einem frueheren
# Lauf schon heruntergeladen wurde), spotdl unterscheidet die beiden Faelle in der JSON nicht.
# download_url wird nur genutzt, um bei frisch heruntergeladenen Tracks den Provider (Host der URL)
# anzuzeigen; --save-errors schreibt Fehlermeldungen zeilenweise in eine Textdatei, die
# best-effort gegen den Tracknamen gematcht wird (siehe Intent 38).
class DownloadResultParser
  Result = Struct.new(:downloaded, :failed)

  PROVIDER_NAMES = {
    "youtube.com" => "YouTube",
    "www.youtube.com" => "YouTube",
    "youtu.be" => "YouTube"
  }.freeze

  UNKNOWN_PROVIDER = "unbekannt"
  DEFAULT_FAILURE_REASON = "Kein Treffer gefunden"

  # Landet im Session-Flash (Cookie, ~4KB-Limit insgesamt, verschluesselt+Base64-kodiert - das
  # kostet real gemessen etwa das 1.5-2-fache der Rohgroesse). Name und Grund werden deshalb
  # knapp gehalten, siehe auch PlaylistsController::MAX_FLASH_ENTRIES.
  MAX_REASON_LENGTH = 80
  MAX_NAME_LENGTH = 60

  def initialize(tracks, save_file_path:, errors_file_path:, cleanup_save_file: false)
    @tracks = tracks
    @save_file_path = downloads_dir.join(save_file_path)
    @errors_file_path = downloads_dir.join(errors_file_path)
    @cleanup_save_file = cleanup_save_file
  end

  def parse
    Track.preload_track_paths(@tracks)
    songs_by_spotify_id = load_songs
    error_lines = load_error_lines
    result = build_result(songs_by_spotify_id, error_lines)
    cleanup
    result
  end

  private

  def downloads_dir
    Rails.root.join(DownloadPlaylistService::TRACKS_DIR)
  end

  def build_result(songs_by_spotify_id, error_lines)
    Result.new(downloaded_entries(songs_by_spotify_id), failed_entries(error_lines))
  end

  def downloaded_entries(songs_by_spotify_id)
    @tracks.filter_map do |track|
      next unless track.track_path

      song = songs_by_spotify_id[track.spotify_id]
      provider = song && song["download_url"].present? ? provider_name(song["download_url"]) : UNKNOWN_PROVIDER
      { name: truncated_name(track), provider: provider }
    end
  end

  def failed_entries(error_lines)
    @tracks.filter_map do |track|
      next if track.track_path

      { name: truncated_name(track), reason: failure_reason(track, error_lines) }
    end
  end

  def truncated_name(track)
    track.name.truncate(MAX_NAME_LENGTH)
  end

  # spotdl sync schreibt {"songs": [...]}, spotdl download (Kleinbatch, siehe
  # DownloadPlaylistCommandBuilder#small_batch?) dagegen ein flaches Array - beide Formen kommen
  # in der Praxis vor.
  def load_songs
    data = JSON.parse(File.read(@save_file_path))
    songs = data.is_a?(Array) ? data : data["songs"]
    songs.index_by { |song| song["song_id"] }
  rescue Errno::ENOENT, JSON::ParserError => e
    Rails.logger.warn("DownloadResultParser: #{@save_file_path} nicht lesbar: #{e.message}")
    {}
  end

  def load_error_lines
    File.readlines(@errors_file_path, chomp: true)
  rescue Errno::ENOENT
    []
  end

  def failure_reason(track, error_lines)
    matching_line = error_lines.find { |line| line.include?(track.name) }
    matching_line ? matching_line.truncate(MAX_REASON_LENGTH) : DEFAULT_FAILURE_REASON
  end

  def provider_name(download_url)
    host = URI(download_url).host
    return "Bandcamp" if host&.end_with?("bandcamp.com")

    PROVIDER_NAMES[host] || host
  rescue URI::InvalidURIError
    download_url
  end

  def cleanup
    File.delete(@errors_file_path) if File.exist?(@errors_file_path)
    File.delete(@save_file_path) if @cleanup_save_file && File.exist?(@save_file_path)
  end
end
