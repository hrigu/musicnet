# frozen_string_literal: true

class CreateLibraries < ActiveRecord::Migration[8.1]
  def change
    create_table :libraries do |t|
      t.string :name, null: false
      t.string :keyword, null: false

      t.timestamps
    end
    add_index :libraries, :name, unique: true
  end
end
