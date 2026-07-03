# frozen_string_literal: true

require "ostruct"

class Track < ApplicationRecord
  belongs_to :album
  has_and_belongs_to_many :artists
  has_many :playlist_tracks

  # Die Playlist die diesen Track enthlten
  has_many :playlists, through: :playlist_tracks

  def self.for_index
    includes(:artists, { playlist_tracks: :playlist }, :album).order(:name).strict_loading
  end

  def self.for_download
    tracks = includes(:playlists).strict_loading.to_a
    preload_track_paths(tracks)
    tracks
  end

  # Löst die Pfade aller Tracks mit einem einzigen Verzeichnis-Scan auf. Ohne Preload liest
  # track_path das Verzeichnis pro Track — bei tausenden Tracks dauert die Index-Seite
  # sonst zwanzig Sekunden statt zwei.
  def self.preload_track_paths(tracks)
    TrackFileLocator.preload_track_paths(tracks)
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

    @track_path = TrackFileLocator.resolve_track_path(self)
  end

  private

  def read_genre_from_file
    return unless track_path

    WahWah.open(track_path).genre
  rescue WahWah::WahWahArgumentError, WahWah::WahWahNotImplementedError
    # Datei existiert, aber WahWah kann sie nicht parsen (z.B. unbekanntes Format).
    nil
  end

  # {"acousticness"=>0.552, "analysis_url"=>"https://api.spotify.com/v1/audio-analysis/2uSavRrWjouarU9DupcWmK", "danceability"=>0.69, "duration_ms"=>296333, "energy"=>0.553, "instrumentalness"=>0.914, "key"=>5, "liveness"=>0.121, "loudness"=>-12.152, "mode"=>1, "speechiness"=>0.0372, "tempo"=>131.674, "time_signature"=>4, "track_href"=>"https://api.spotify.com/v1/tracks/2uSavRrWjouarU9DupcWmK", "valence"=>0.917, "external_urls"=>nil, "href"=>nil, "id"=>"2uSavRrWjouarU9DupcWmK", "type"=>"audio_features", "uri"=>"spotify:track:2uSavRrWjouarU9DupcWmK"}
end
