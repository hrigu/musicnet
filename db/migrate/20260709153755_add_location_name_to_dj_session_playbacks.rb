# frozen_string_literal: true

class AddLocationNameToDjSessionPlaybacks < ActiveRecord::Migration[8.1]
  def change
    add_column :dj_session_playbacks, :location_name, :string
  end
end
