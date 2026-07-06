class Library < ApplicationRecord
  has_many :library_playlists, dependent: :destroy
  has_many :playlists, through: :library_playlists

  validates :name, presence: true, uniqueness: true
  validates :keyword, presence: true

  # Einzige Stelle, die den Stichwort-Teilstring-Vergleich durchfuehrt - sowohl der
  # Spotify-Import-Filter als auch die automatische Playlist-Zuordnung nutzen ausschliesslich
  # diese Methode (Intent 57).
  def self.matching(playlist_name)
    all.select { |library| playlist_name.downcase.include?(library.keyword.downcase) }
  end
end
