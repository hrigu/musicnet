# Eine JoinTabelle mit der zusätzlichen Information, wann der Track zur Playlist hinzgefügt wurde (:added_at)
class PlaylistTrack < ApplicationRecord
  belongs_to :playlist
  belongs_to :track
end
