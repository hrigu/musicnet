class Library < ApplicationRecord
  has_many :library_playlists, dependent: :destroy
  has_many :playlists, through: :library_playlists
  # Verhindert einen verwaisten Fremdschluessel (users.active_library_id) beim Loeschen einer
  # gerade aktiven Library - "Alle" (nil) ist immer ein gueltiger Zustand (Intent 57).
  has_many :users, foreign_key: :active_library_id, inverse_of: :active_library, dependent: :nullify

  validates :name, presence: true, uniqueness: true
  validates :keyword, presence: true

  # Einzige Stelle, die den Stichwort-Teilstring-Vergleich durchfuehrt - sowohl der
  # Spotify-Import-Filter als auch die automatische Playlist-Zuordnung nutzen ausschliesslich
  # diese Methode (Intent 57).
  def self.matching(playlist_name)
    all.select { |library| playlist_name.downcase.include?(library.keyword.downcase) }
  end
end
