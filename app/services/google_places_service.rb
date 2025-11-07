require 'httparty'
require 'json'

class GooglePlacesService 
  BASE_URL = "https://maps.googleapis.com/maps/api/place/textsearch/json"

  def initialize(api_key = ENV['GOOGLE_PLACES_API_KEY'])
    @api_key = api_key
  end

  # Fetch real restaurants
  # city: string, category: string (optional), price_level: 0..4 (optional)
  def fetch_restaurants(city:, category: nil, price_level: nil, limit: 1)
    restaurants = []
    query = "restaurants in #{city}"
    query += " #{category}" if category.present?
  
    params = {
      query: query,
      key: @api_key,
      type: 'restaurant'
    }
    params[:maxprice] = price_level if price_level.present?
  
    url = BASE_URL
    loop do
      response = HTTParty.get(url, query: params)
      data = JSON.parse(response.body)
      results = data['results'] || []
      
      restaurants += results.map do |r|
        {
          name: r['name'],
          address: r['formatted_address'],
          rating: r['rating'],
          price: r['price_level'] ? ('$' * r['price_level']) : nil,
          place_id: r['place_id'],
          latitude: r['geometry']['location']['lat'],
          longitude: r['geometry']['location']['lng'],
          zip_code: nil,
          category: category || "Restaurant",
          food_type: category || "Various",
          description: r['description'],
          delivery_option: false,
          vegan_friendly: false,
          kid_friendly: false,
          parking: "Street",
          opening_hours: nil,
          website: nil,
          email: nil
        }
      end
  
      break if restaurants.size >= limit || data['next_page_token'].blank?
  
      # Google requires a short delay before using next_page_token
      sleep 2
      params = { key: @api_key, pagetoken: data['next_page_token'] }
    end
  
    restaurants.first(limit)
  end
end  