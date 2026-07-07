class CreateTags < ActiveRecord::Migration[8.1]
  def change
    create_table :tags do |t|
      t.references :category, null: false, foreign_key: true
      t.string :name, null: false
      # Kommagetrennte Roh-Stichwoerter (Intent 77), z.B. "melancolic, melancolia,
      # melancholia" - im Admin-UI als einfaches Textfeld editierbar, keine eigene
      # Join-Tabelle noetig.
      t.text :aliases, null: false

      t.timestamps
    end
    add_index :tags, %i[category_id name], unique: true
  end
end
