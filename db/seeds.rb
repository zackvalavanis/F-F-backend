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

# user = User.find_or_create_by!(email: "test@example.com") do |u|
#   u.name = "Test User"
#   u.password = "password"              # virtual attribute provided by has_secure_password
#   u.password_confirmation = "password" # optional, only if you want to check confirmation
# end

# recipe = Recipe.create!(
#   user: user, # assign the user directly
#   title: "Honey Garlic Chicken",
#   prep_time: 25,
#   cook_time: 20,
#   servings: 2,
#   difficulty: 5,
#   tags: "Dinner",
#   category: "Dinner",
#   rating: 6,
#   description: "Honey garlic sauce with chicken",
#   ingredients: "chicken",
#   directions: ''
# )

# user = User.first

# Recipe.create!(
#   user: user,
#   title: "Spaghetti Carbonara",
#   prep_time: 10,
#   cook_time: 15,
#   servings: 2,
#   difficulty: 2,
#   tags: "Pasta, Italian, Quick, Dinner",
#   category: "Dinner",
#   rating: 5,
#   description: "Classic Italian pasta with creamy egg sauce, pancetta, and Parmesan.",
#   ingredients: "spaghetti, eggs, pancetta, Parmesan cheese, black pepper",
#   directions: "1. Cook spaghetti until al dente. 2. Cook pancetta until crisp. 3. Whisk eggs and Parmesan together. 4. Combine pasta, pancetta, and egg mixture off heat. 5. Season with black pepper and serve."
# )

# Recipe.create!(
#   user: user,
#   title: "Vegetable Stir Fry",
#   prep_time: 10,
#   cook_time: 10,
#   servings: 2,
#   difficulty: 1,
#   tags: "Vegetarian, Quick, Healthy, Dinner",
#   category: "Dinner",
#   rating: 5,
#   description: "A colorful mix of vegetables sautéed in a savory soy garlic sauce.",
#   ingredients: "broccoli, bell peppers, carrots, soy sauce, garlic, olive oil",
#   directions: "1. Heat olive oil in a pan. 2. Add garlic and sauté 1 min. 3. Add vegetables and stir fry 5-7 mins. 4. Add soy sauce and cook 2 more mins. 5. Serve over rice or noodles."
# )

# Recipe.create!(
#   user: user,
#   title: "Pancakes",
#   prep_time: 10,
#   cook_time: 15,
#   servings: 4,
#   difficulty: 2,
#   tags: "Breakfast, Sweet, Quick, Vegetarian",
#   category: "Breakfast",
#   rating: 5,
#   description: "Fluffy homemade pancakes perfect for breakfast or brunch.",
#   ingredients: "flour, milk, eggs, sugar, baking powder, butter",
#   directions: "1. Mix dry ingredients in a bowl. 2. Whisk wet ingredients separately. 3. Combine wet and dry ingredients until smooth. 4. Cook on a greased skillet until golden on both sides. 5. Serve with syrup or fruit."
# )

# Recipe.create!(
#   user: user,
#   title: "Shrimp Tacos",
#   prep_time: 15,
#   cook_time: 10,
#   servings: 2,
#   difficulty: 3,
#   tags: "Seafood, Mexican, Quick, Dinner",
#   category: "Dinner",
#   rating: 6,
#   description: "Spicy shrimp tacos with fresh slaw and creamy sauce, ready in 25 minutes.",
#   ingredients: "shrimp, taco shells, cabbage, lime, sour cream, chili powder, garlic",
#   directions: "1. Season shrimp with chili powder and garlic. 2. Cook shrimp in a skillet 3-4 mins. 3. Mix cabbage with lime and sour cream for slaw. 4. Assemble tacos with shrimp and slaw. 5. Serve immediately."
# )

# Recipe.create!(
#   user: user,
#   title: "Chocolate Chip Cookies",
#   prep_time: 15,
#   cook_time: 12,
#   servings: 24,
#   difficulty: 2,
#   tags: "Dessert, Sweet, Baking, Snack",
#   category: "Dessert",
#   rating: 6,
#   description: "Classic chewy chocolate chip cookies with a golden brown edge.",
#   ingredients: "flour, butter, sugar, brown sugar, eggs, vanilla, chocolate chips, baking soda, salt",
#   directions: "Preheat oven to 350°F (175°C). Cream butter and sugars. Add eggs and vanilla. Mix in flour, baking soda, and salt. Fold in chocolate chips. Scoop onto baking sheet and bake 10-12 mins. Cool before serving."
# )

# # Seed 1
# restaurant = Restaurant.create!(
#   name: "Bella Napoli",
#   price: 3,
#   rating: 9,
#   food_type: "Italian",
#   category: "Fine Dining",
#   description: "Authentic Italian cuisine with fresh pasta and wood-fired pizzas.",
#   phone_number: "312-555-1234",
#   website: "https://bellanapoli.example.com",
#   email: "info@bellanapoli.example.com",
#   address: "123 Main St",
#   city: "Chicago",
#   state: "IL",
#   zip_code: "60601",
#   latitude: 41.8781,
#   longitude: -87.6298,
#   opening_hours: "Mon-Sun 11:00-22:00",
#   delivery_option: false,
#   vegan_friendly: true,
#   kid_friendly: false,
#   parking: "Street"
# )

# # Seed 2
# restaurant = Restaurant.create!(
#   name: "Taco Haven",
#   price: 1,
#   rating: 7,
#   food_type: "Mexican",
#   category: "Casual",
#   description: "Quick and delicious tacos, burritos, and quesadillas for lunch or dinner.",
#   phone_number: "312-555-5678",
#   website: "https://tacohaven.example.com",
#   email: "contact@tacohaven.example.com",
#   address: "456 Elm St",
#   city: "Chicago",
#   state: "IL",
#   zip_code: "60605",
#   latitude: 41.8819,
#   longitude: -87.6278,
#   opening_hours: "Mon-Fri 10:00-21:00, Sat-Sun 11:00-22:00",
#   delivery_option: true,
#   vegan_friendly: false,
#   kid_friendly: true,
#   parking: "Garage"
# )


# Recipe.create!(
#   user: user,
#   title: "potatoes",
#   prep_time: 10,
#   cook_time: 10,
#   servings: 2,
#   difficulty: 1,
#   tags: "Vegetarian, Quick, Healthy, Dinner",
#   category: "Dinner",
#   rating: 10,
#   description: "A colorful mix of vegetables sautéed in a savory soy garlic sauce.",
#   ingredients: "broccoli, bell peppers, carrots, soy sauce, garlic, olive oil",
#   directions: "Heat olive oil in a pan. Add garlic and sauté 1 min. Add vegetables and stir fry 5-7 mins. Add soy sauce and cook 2 more mins. Serve over rice or noodles."
# )

file_path = Rails.root.join("app/assets/images/istockphoto-517188688-612x612.jpg")

if File.exist?(file_path)
  restaurant = Restaurant.first
  restaurant.images.attach(
    io: File.open(file_path),
    filename: "istockphoto-517188688-612x612.jpg",
    content_type: "image/jpeg"
  )
else
  puts "File not found: #{file_path}"
end


# restaurant = Restaurant.second
# restaurant.images.attach(
#   io: File.open(Rails.root.join("app/assets/images/taco.jpg")),
#   filename: "taco.jpg",
#   content_type: "image/jpeg"
# )
