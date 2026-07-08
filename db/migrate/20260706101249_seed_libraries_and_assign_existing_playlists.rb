# frozen_string_literal: true

# Seedet die zwei bisher hardcoded Kategorien als echte Library-Datensaetze und ordnet alle
# schon lokal vorhandenen Playlists nach ihrem aktuellen Namen zu (Intent 57) - damit sich am
# Ist-Zustand nach der Migration nichts aendert. Lokale Modelle statt der App-Models, damit diese
# Migration auch nach spaeteren Aenderungen an Library/Playlist unveraendert lauffaehig bleibt.
class SeedLibrariesAndAssignExistingPlaylists < ActiveRecord::Migration[8.1]
  class MigrationLibrary < ActiveRecord::Base
    self.table_name = "libraries"
  end

  class MigrationPlaylist < ActiveRecord::Base
    self.table_name = "playlists"
  end

  class MigrationLibraryPlaylist < ActiveRecord::Base
    self.table_name = "library_playlists"
  end

  def up
    libraries = [
      MigrationLibrary.create!(name: "Blues", keyword: "blues"),
      MigrationLibrary.create!(name: "Fusion", keyword: "fusion")
    ]

    MigrationPlaylist.find_each do |playlist|
      libraries.each do |library|
        next unless playlist.name.to_s.downcase.include?(library.keyword.downcase)

        MigrationLibraryPlaylist.create!(library_id: library.id, playlist_id: playlist.id)
      end
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
