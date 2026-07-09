# frozen_string_literal: true

class CreateTagAssignments < ActiveRecord::Migration[8.1]
  def change
    create_table :tag_assignments do |t|
      t.references :user, null: false, foreign_key: true
      t.references :tag, null: false, foreign_key: true

      t.timestamps
    end

    add_index :tag_assignments, %i[user_id created_at]
    add_index :tag_assignments, %i[user_id tag_id created_at]
  end
end
