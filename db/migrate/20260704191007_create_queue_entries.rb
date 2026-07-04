class CreateQueueEntries < ActiveRecord::Migration[8.1]
  def change
    create_table :queue_entries do |t|
      t.references :track, null: false, foreign_key: true

      t.timestamps
    end
  end
end
