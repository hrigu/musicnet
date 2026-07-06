class LibraryPlaylist < ApplicationRecord
  belongs_to :library
  belongs_to :playlist
end
