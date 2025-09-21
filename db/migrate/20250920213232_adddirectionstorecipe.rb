class Adddirectionstorecipe < ActiveRecord::Migration[7.1]
  def change
    add_column :recipes, :directions, :text
  end

end
