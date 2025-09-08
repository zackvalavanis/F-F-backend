# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end
#   
#
#

user = User.find_or_create_by!(email: "test@example.com") do |u|
  u.name = "Test User"
  u.password = "password"              # virtual attribute provided by has_secure_password
  u.password_confirmation = "password" # optional, only if you want to check confirmation
end

recipe = Recipe.create!(
  user: user, # assign the user directly
  title: "Honey Garlic Chicken",
  prep_time: 25,
  cook_time: 20,
  servings: 2,
  difficulty: 5,
  tags: "Dinner",
  category: "Dinner",
  rating: 6,
  description: "Honey garlic sauce with chicken",
  ingredients: "chicken"
)
