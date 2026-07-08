# frozen_string_literal: true

# Legt die Kategorie "Auftrittsdatum" an (Intent 78) - anders als die übrigen Kategorien bekommt
# sie keine fest kuratierten Tags: die Tags (ein Datum pro tatsächlichem DJ-Auftritt, z.B.
# "2023-12-01") werden dynamisch vom Rake-Task assign_track_tags direkt aus dem Datums-Präfix im
# Playlist-Namen erzeugt, da die Menge möglicher Daten nicht im Voraus aufzählbar ist (anders als
# die restliche, feste Taxonomie aus SeedCategoriesAndTags, Intent 77). Lokales Modell statt des
# App-Models, damit diese Migration auch nach späteren Änderungen an Category unverändert
# lauffähig bleibt (gleiches Muster wie SeedCategoriesAndTags).
class AddAuftrittsdatumCategory < ActiveRecord::Migration[8.1]
  class MigrationCategory < ActiveRecord::Base
    self.table_name = "categories"
  end

  def up
    MigrationCategory.find_or_create_by!(name: "Auftrittsdatum") do |c|
      c.is_event = true
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
