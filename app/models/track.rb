# frozen_string_literal: true

require "ostruct"

class Track < ApplicationRecord
  belongs_to :album
  has_and_belongs_to_many :artists
  has_many :playlist_tracks

  # Die Playlist die diesen Track enthlten
  has_many :playlists, through: :playlist_tracks

  # Zeichen, die spotdl in Dateinamen weglässt oder anders schreibt. Backslashes fliegen
  # raus, weil das frühere Glob sie als Escape-Zeichen verschluckt hat (z.B. "Sittin\' And
  # Cryin\' The Blues") — das Matching muss das replizieren.
  FILE_NAME_REPLACEMENTS = { ':' => '-', '?' => '', '/' => '', '"' => '\'', '\\' => '' }.freeze

  # Löst die Pfade aller Tracks mit einem einzigen Verzeichnis-Scan auf. Ohne Preload liest
  # track_path das Verzeichnis pro Track — bei tausenden Tracks dauert die Index-Seite
  # sonst zwanzig Sekunden statt zwei.
  def self.preload_track_paths(tracks)
    file_entries = download_file_entries
    tracks.each { |track| track.resolve_track_path(file_entries) }
  end

  # Paare aus Original- und kleingeschriebenem Dateinamen — einmal downcasen statt
  # pro Track-Vergleich (bei 2466 Tracks × 2270 Dateien spart das über eine Sekunde).
  # Dotfiles fliegen wie beim früheren Glob raus. downloads/ ist gitignored — auf
  # einem frischen Checkout fehlt das Verzeichnis.
  def self.download_file_entries
    return [] unless Dir.exist?(downloads_dir)

    Dir.children(downloads_dir).sort
       .reject { |file_name| file_name.start_with?('.') }
       .map { |file_name| [file_name, file_name.downcase] }
  end

  def self.downloads_dir
    Rails.root.join('downloads/tracks')
  end

  def dauer
    Time.at(duration_ms / 1000).utc.strftime('%M:%S')
  end

  # Siehe @RSpotify::Audiofeatures
  # - acousticness:     [Float] danceability Danceability describes how suitable a track is for dancing based on a combination of musical elements including tempo, rhythm stability, beat strength, and overall regularity. A value of 0.0 is least danceable and 1.0 is most danceable.
  # - mode:             Major, Minor (Oder 1 und 0)
  # - energy:           Float
  # - instrumentalness  Float
  # - liveness          Float
  # - loudness          Float
  # - speechiness       [Float] tempo The overall estimated tempo of a track in beats per minute (BPM). In musical terminology, tempo is the speed or pace of a given piece and derives directly from the average beat duration.
  # - time_signature    Integer
  # - valence           Float
  #
  # - duration_ms
  # - analysis_url
  # - key
  # - href
  # - id
  # - type
  # - uri
  def af
    @af ||= audio_features.present? ? JSON.parse(audio_features, object_class: OpenStruct) : nil
  end

  def energy
    af.try(:energy)
  end

  def tempo
    af.try(:tempo)
  end

  # Das Genre, wird aus dem runtergeladenen File gelesen und als Read-Through-Cache in der
  # DB abgelegt — es ändert sich praktisch nie, das Datei-Parsen kostet aber ~1.3s pro
  # Index-Aufruf. Invalidierung bewusst manuell via Track.update_all(genre: nil), siehe
  # Intent 28. update_column, weil es nur ein Cache ist (keine Callbacks, updated_at bleibt).
  def genre
    return self[:genre] if self[:genre].present?

    value = read_genre_from_file
    update_column(:genre, value) if value.present? && persisted?
    value
  end

  # @return den absoluten Pfad zum runtergeladenen Lied. Wird aus dem Namen des Tracks bestimmt.
  # Gewisse Zeichen werden im Pfad nicht oder anders verwendet, darum zuerst ersetzen.
  # Der Interpret ist meistens im Namen des Files auch vorhanden. Wird hier nicht berücksichtigt.
  # nil (Datei fehlt) ist ein gültiger Wert und wird mit-memoisiert, darum defined? statt ||=.
  def track_path
    return @track_path if defined?(@track_path)

    resolve_track_path(self.class.download_file_entries)
  end

  # Repliziert die frühere Glob-Semantik "*-?<name>.m4a": Dateiname endet auf <name>.m4a,
  # davor ein beliebiges Zeichen, davor ein Bindestrich. Wie das Glob auf macOS
  # case-insensitiv (darum der Vergleich auf dem kleingeschriebenen Namen).
  def resolve_track_path(file_entries)
    search = name.gsub(Regexp.union(FILE_NAME_REPLACEMENTS.keys), FILE_NAME_REPLACEMENTS)
    suffix = "#{search}.m4a".downcase
    entry = file_entries.find { |_original, downcased| file_name_matches?(downcased, suffix) }
    Rails.logger.info("!!File nicht gefunden: #{search}") unless entry
    @track_path = entry && self.class.downloads_dir.join(entry.first).to_s
  end

  private

  def read_genre_from_file
    return unless track_path

    WahWah.open(track_path).genre
  rescue WahWah::WahWahArgumentError, WahWah::WahWahNotImplementedError
    # Datei existiert, aber WahWah kann sie nicht parsen (z.B. unbekanntes Format).
    nil
  end

  def file_name_matches?(file_name, suffix)
    file_name.end_with?(suffix) &&
      file_name.length >= suffix.length + 2 &&
      file_name[file_name.length - suffix.length - 2] == '-'
  end

  # {"acousticness"=>0.552, "analysis_url"=>"https://api.spotify.com/v1/audio-analysis/2uSavRrWjouarU9DupcWmK", "danceability"=>0.69, "duration_ms"=>296333, "energy"=>0.553, "instrumentalness"=>0.914, "key"=>5, "liveness"=>0.121, "loudness"=>-12.152, "mode"=>1, "speechiness"=>0.0372, "tempo"=>131.674, "time_signature"=>4, "track_href"=>"https://api.spotify.com/v1/tracks/2uSavRrWjouarU9DupcWmK", "valence"=>0.917, "external_urls"=>nil, "href"=>nil, "id"=>"2uSavRrWjouarU9DupcWmK", "type"=>"audio_features", "uri"=>"spotify:track:2uSavRrWjouarU9DupcWmK"}
end
