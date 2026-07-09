# frozen_string_literal: true

class AddAssignableToTags < ActiveRecord::Migration[8.1]
  def change
    add_column :tags, :assignable, :boolean, null: false, default: true
  end
end
