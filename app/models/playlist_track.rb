# frozen_string_literal: true

# Eine JoinTabelle mit der zusätzlichen Information, wann der Track zur Playlist hinzgefügt wurde (:added_at)
class PlaylistTrack < ApplicationRecord
  belongs_to :playlist, counter_cache: :tracks_count
  belongs_to :track
end
