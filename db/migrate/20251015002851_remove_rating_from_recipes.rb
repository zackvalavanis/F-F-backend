class RemoveRatingFromRecipes < ActiveRecord::Migration[7.1]
  def change
    remove_column :recipes, :rating, :integer
  end
end
