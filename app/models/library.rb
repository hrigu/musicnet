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

  # Ergaenzt Library.matching/assign_libraries (die nur beim Spotify-Sync greifen) um die
  # umgekehrte Richtung: bereits lokal vorhandene Playlists werden ohne einen erneuten Sync
  # abzuwarten dieser einen Library zugeordnet bzw. wieder entfernt, sobald ihr Stichwort neu
  # gesetzt/geaendert wird (Intent 57, manuell entdeckte Luecke).
  def resync_playlist_assignments!
    Playlist.find_each do |playlist|
      matches = playlist.name.to_s.downcase.include?(keyword.downcase)
      if matches
        library_playlists.find_or_create_by!(playlist: playlist)
      else
        library_playlists.where(playlist: playlist).destroy_all
      end
    end
  end
end
