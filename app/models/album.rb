# frozen_string_literal: true

class Album < ApplicationRecord
  # Die Tracks des Albums, die in mindestens einer Playlist vorhanden sind
  has_many :tracks
  # Die Künstler welche auf den Tracks
  has_many :artists, -> { distinct }, through: :tracks
end
