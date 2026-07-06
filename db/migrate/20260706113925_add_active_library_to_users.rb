# Ersetzt den festen Enum active_playlist_category (Intent 54) durch eine Referenz auf eine
# echte Library (Intent 57) - nil bedeutet weiterhin "Alle" (kein Filter). Uebernimmt bestehende
# Werte 1:1 ("blues"/"fusion" -> die per Task 1.3 geseedete gleichnamige Library, alles andere ->
# nil), damit sich am eingestellten Filter fuer bestehende User nichts aendert. Lokale Modelle
# statt der App-Models, damit diese Migration auch nach spaeteren Aenderungen lauffaehig bleibt.
class AddActiveLibraryToUsers < ActiveRecord::Migration[8.1]
  class MigrationUser < ActiveRecord::Base
    self.table_name = "users"
  end

  class MigrationLibrary < ActiveRecord::Base
    self.table_name = "libraries"
  end

  def up
    add_reference :users, :active_library, null: true, foreign_key: { to_table: :libraries }

    blues_id = MigrationLibrary.find_by(name: "Blues")&.id
    fusion_id = MigrationLibrary.find_by(name: "Fusion")&.id
    category_to_library_id = { "blues" => blues_id, "fusion" => fusion_id }

    MigrationUser.reset_column_information
    MigrationUser.find_each do |user|
      library_id = category_to_library_id[user.active_playlist_category]
      user.update!(active_library_id: library_id) if library_id
    end

    remove_column :users, :active_playlist_category, :string
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
