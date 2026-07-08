# frozen_string_literal: true

class CreateCategories < ActiveRecord::Migration[8.1]
  def change
    create_table :categories do |t|
      t.string :name, null: false
      t.string :color
      # "Anlass/Ort" markiert einen Live-Auftritt statt einer musikalischen Eigenschaft
      # (Intent 77) - UI/Suche koennen so unterscheiden, ohne den Kategorienamen zu parsen.
      t.boolean :is_event, null: false, default: false

      t.timestamps
    end
    add_index :categories, :name, unique: true
  end
end
