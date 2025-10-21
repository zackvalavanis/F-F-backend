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
    price = params[:price]
    save_to_db = ActiveModel::Type::Boolean.new.cast(params[:save])

    prompt_data = build_restaurant_prompt(city: city, category: category, price: price)

    openai = OpenaiService.new
    ai_response = openai.chat_system_user(prompt_data[:system], prompt_data[:user], temperature: 0.7)
    restaurant_json = JSON.parse(ai_response)

    if save_to_db
      restaurant = Restaurant.create(restaurant_json)
      render json: restaurant, status: :created
    else
      render json: restaurant_json
    end

  rescue JSON::ParserError => e
    render json: { error: "Invalid JSON returned by AI: #{e.message}" }, status: :unprocessable_entity
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

    user_message = "Generate a restaurant"
    user_message += " in city: #{city}" if city.present?
    user_message += " with category: #{category}" if category.present?
    user_message += " with price: #{price}" if price.present?
    user_message += ". Return JSON only."

    { system: system_message, user: user_message }
  end
end
