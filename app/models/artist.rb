class Artist < ApplicationRecord
  # Die Tracks in welchen der Künstler mitwirkt.
  has_and_belongs_to_many :tracks

  # Alle Alben der Tracks in welchen der Künstler mitwirkt
  has_many :albums, -> { distinct }, through: :tracks
end
