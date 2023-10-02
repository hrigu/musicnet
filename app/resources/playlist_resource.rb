class PlaylistResource < ApplicationResource
  self.description = "Die Playlist"
  attribute :name, :string, description: "huhu"
  attribute :public, :boolean


end
