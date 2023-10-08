# frozen_string_literal: true

class Artist < ApplicationRecord
  # Die Tracks in welchen der Künstler mitwirkt.
  has_and_belongs_to_many :tracks

  # Alle Alben der Tracks in welchen der Künstler mitwirkt
  has_many :albums, -> { distinct }, through: :tracks

  def playlists_of_the_tracks
    Playlist.distinct.joins(playlist_tracks: { track: :artists }).where(artists: { id: id })
  end
end
