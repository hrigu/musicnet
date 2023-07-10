class Playlist < ApplicationRecord
  has_many :playlist_tracks
  has_many :tracks, through: :playlist_tracks

  def name_path_ready
    name.delete(" ")
  end
end
