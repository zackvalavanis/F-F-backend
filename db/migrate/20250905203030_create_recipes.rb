class CreateRecipes < ActiveRecord::Migration[7.1]
  def change
    create_table :recipes do |t|
      t.integer :user_id
      t.string :title
      t.integer :prep_time
      t.integer :cook_time
      t.integer :servings
      t.integer :difficulty
      t.string :tags
      t.string :category
      t.integer :rating
      t.text :description
      t.text :ingredients

      t.timestamps
    end
  end
end
