# frozen_string_literal: true

class Track < ApplicationRecord
  belongs_to :album
  has_and_belongs_to_many :artists
  has_many :playlist_tracks

  # Die Playlist die diesen Track enthlten
  has_many :playlists, through: :playlist_tracks

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

  # Das Genre, wird aus dem runtergeladenen File gelesen
  def genre
    return unless track_path
    begin
      WahWah.open(track_path).genre
    rescue
      # kann irgendwie nil sein.
      nil
    end
  end

  # @return den Pfad zum rungereladenen Lied. Wird aus dem Namen des Tracks bestimmt.
  # Gewisse Zeichen werden im Pfad nicht oder anders verwendet, darum zuerst ersetzen.
  # Der Interpret ist meistens im Namen des Files auch vorhanden. Wird hier nicht berücksichtigt.
  def track_path
    search = name

    replacements = { ':' => '-', '?' => '', '/' => '', '"' => '\'', '[' => '\[', ']' => '\]' }
    search.gsub!(Regexp.union(replacements.keys), replacements)
    dir_name = Rails.root.join('downloads/tracks')
    Dir.chdir dir_name
    files = Dir.glob("*-?#{search}.m4a")
    if files.first
      # Rails.logger.info("File gefunden: #{search}")
    else
      Rails.logger.info("!!File nicht gefunden: #{search}")
    end
    files.first
  end

  # {"acousticness"=>0.552, "analysis_url"=>"https://api.spotify.com/v1/audio-analysis/2uSavRrWjouarU9DupcWmK", "danceability"=>0.69, "duration_ms"=>296333, "energy"=>0.553, "instrumentalness"=>0.914, "key"=>5, "liveness"=>0.121, "loudness"=>-12.152, "mode"=>1, "speechiness"=>0.0372, "tempo"=>131.674, "time_signature"=>4, "track_href"=>"https://api.spotify.com/v1/tracks/2uSavRrWjouarU9DupcWmK", "valence"=>0.917, "external_urls"=>nil, "href"=>nil, "id"=>"2uSavRrWjouarU9DupcWmK", "type"=>"audio_features", "uri"=>"spotify:track:2uSavRrWjouarU9DupcWmK"}
end
