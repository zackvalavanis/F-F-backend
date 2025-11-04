require 'openai'
require 'open-uri'
require 'json'

class RestaurantsController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :set_restaurant, only: [:show, :update, :destroy]

  # GET /restaurants
  def index
    @restaurants = Restaurant.all
    @restaurants = @restaurants.where(price: params[:price]) if params[:price].present?
    @restaurants = @restaurants.where('rating >= ?', params[:min_rating].to_i) if params[:min_rating].present?
    @restaurants = @restaurants.where(city: params[:city]) if params[:city].present?
    @restaurants = @restaurants.where('food_type ILIKE ?', "%#{params[:food_type]}%") if params[:food_type].present?
    render :index
  end

  # GET /restaurants/:id
  def show
    render json: @restaurant
  end

  # POST /restaurants
  def create
    @restaurant = Restaurant.new(restaurant_params)
    if @restaurant.save
      render json: @restaurant, status: :created
    else
      render json: { errors: @restaurant.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /restaurants/:id
  def update
    if @restaurant.update(restaurant_params)
      render json: @restaurant
    else
      render json: { errors: @restaurant.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # DELETE /restaurants/:id
  def destroy
    @restaurant.destroy
    head :no_content
  end

  # =============================
  # AI generate restaurant action
  # =============================
  def generate_restaurant
    city = params[:city]
    category = params[:category]
    price_level = params[:price_level]&.to_i
    save_to_db = ActiveModel::Type::Boolean.new.cast(params[:save])
  
    places_service = GooglePlacesService.new
    real_restaurants = places_service.fetch_restaurants(
      city: city,
      category: category,
      price_level: price_level
    )
  
    enriched_restaurants = real_restaurants.map do |r|
      {
        name: r[:name],
        address: r[:address],
        city: city,
        state: "IL",
        zip_code: nil,
        rating: r[:rating] || nil,
        price: r[:price] || nil,
        latitude: r[:latitude],
        longitude: r[:longitude],
        category: category || "Restaurant",
        food_type: category || "Various",
        description: "Delicious #{category || 'food'} in #{city}",
        delivery_option: false,
        vegan_friendly: false,
        kid_friendly: false,
        parking: "Street",
        opening_hours: nil,
        website: nil,
        email: nil
      }
    end
  
    if save_to_db
      restaurants = enriched_restaurants.map do |r|
        restaurant = Restaurant.create(r)
  
        if restaurant.persisted?
          begin
            openai = OpenAI::Client.new(access_token: ENV['OPENAI_API_KEY'])
            prompt = "A photo of #{restaurant.name}, a #{restaurant.category} in #{city}"
            image_resp = openai.images.generate(parameters: { prompt: prompt, size: "512x512" })
            image_url = image_resp.dig("data", 0, "url")
  
            if image_url
              downloaded_image = URI.open(image_url)
              restaurant.images.attach(
                io: downloaded_image,
                filename: "#{restaurant.name.parameterize}.png"
              )
            end
          rescue => e
            Rails.logger.error "Image generation failed for #{restaurant.name}: #{e.message}"
          end
        end
  
        # Return restaurant with image URLs for API
        restaurant.as_json.merge({ images: restaurant.image_urls })
      end
  
      render json: restaurants, status: :created
    else
      render json: enriched_restaurants
    end
  end
  
  
  private

  # Callbacks
  def set_restaurant
    @restaurant = Restaurant.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Restaurant not found' }, status: :not_found
  end

  # Strong parameters
  def restaurant_params
    params.require(:restaurant).permit(
      :name, :price, :rating, :food_type, :category,
      :description, :phone_number, :website, :email,
      :address, :city, :state, :zip_code,
      :latitude, :longitude, :opening_hours,
      :delivery_option, :vegan_friendly, :kid_friendly, :parking
    )
  end

  # Build AI prompt
  def build_restaurant_prompt(city: nil, category: nil, price: nil)
    schema = {
      "name" => "string",
      "food_type" => "string",
      "description" => "string",
      "phone_number" => "string",
      "website" => "string",
      "email" => "string",
      "address" => "string",
      "city" => "string",
      "state" => "string",
      "zip_code" => "string",
      "latitude" => "number",
      "longitude" => "number",
      "opening_hours" => "string",
      "delivery_option" => "boolean",
      "vegan_friendly" => "boolean",
      "kid_friendly" => "boolean",
      "parking" => "string",
      "price" => "string",
      "category" => "string"
    }

    system_message = <<~SYS
      You are a helpful restauranteur. Produce exactly one valid JSON object following this schema (no additional text):
      #{JSON.pretty_generate(schema)}

      - Use null for unknown numeric values.
      - Keep text short and concise.
      - Fill in city, price, and category if provided.
      - Boolean fields should be true/false.
      - Do not include extra explanation or comments.
    SYS

    user_message = "Find a restaurant"
    user_message += " in city: #{city}" if city.present?
    user_message += " with category: #{category}" if category.present?
    user_message += " with price: #{price}" if price.present?
    user_message += ". Return JSON only."

    { system: system_message, user: user_message }
  end
end
