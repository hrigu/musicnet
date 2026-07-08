class AddHiddenForAssignmentToCategories < ActiveRecord::Migration[8.1]
  def change
    add_column :categories, :hidden_for_assignment, :boolean, default: false, null: false
  end
end
