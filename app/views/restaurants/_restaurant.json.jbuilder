
json.id restaurant.id
json.name restaurant.name
json.price restaurant.price
json.rating restaurant.rating
json.food_type restaurant.food_type
json.category restaurant.category
json.description restaurant.description
json.phone_number restaurant.phone_number
json.website restaurant.website
json.email restaurant.email
json.address restaurant.address
json.city restaurant.city
json.state restaurant.state
json.zip_code restaurant.zip_code
json.latitude restaurant.latitude
json.longitude restaurant.longitude
json.opening_hours restaurant.opening_hours
json.delivery_option restaurant.delivery_option
json.vegan_friendly restaurant.vegan_friendly
json.kid_friendly restaurant.kid_friendly
json.parking restaurant.parking
json.created_at restaurant.created_at
json.updated_at restaurant.updated_at
json.images restaurant.images.map { |img| rails_blob_url(img, host: request.base_url) }

