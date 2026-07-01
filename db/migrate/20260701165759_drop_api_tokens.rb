# frozen_string_literal: true

class DropApiTokens < ActiveRecord::Migration[7.1]
  def change
    drop_table :api_tokens do |t|
      t.references :user, null: false, foreign_key: true
      t.boolean :active
      t.text :token
      t.timestamps
    end
  end
end
