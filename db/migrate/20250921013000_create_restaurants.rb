class CreateRestaurants < ActiveRecord::Migration[7.1]
  def change
    create_table :restaurants do |t|
      t.string :name
      t.integer :price
      t.integer :rating
      t.string :food_type
      t.string :category
      t.text :description
      t.string :phone_number
      t.string :website
      t.string :email
      t.string :address
      t.string :city
      t.string :state
      t.string :zip_code
      t.decimal :latitude
      t.decimal :longitude
      t.string :opening_hours
      t.boolean :delivery_option
      t.boolean :vegan_friendly
      t.boolean :kid_friendly
      t.string :parking

      t.timestamps
    end
  end
end
