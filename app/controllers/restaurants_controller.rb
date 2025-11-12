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
    @restaurants = @restaurants.where('rating >= ?', params[:min_rating].to_f) if params[:min_rating].present?
    @restaurants = @restaurants.where(city: params[:city]) if params[:city].present?
    @restaurants = @restaurants.where('food_type ILIKE ?', "%#{params[:food_type]}%") if params[:food_type].present?
    render :index
  end

  # GET /restaurants/:id
  def show
    render json: restaurant_json(@restaurant)
  end

  # POST /restaurants
  def create
    @restaurant = Restaurant.new(restaurant_params)
    if @restaurant.save
      render json: restaurant_json(@restaurant), status: :created
    else
      render json: { errors: @restaurant.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /restaurants/:id
  def update
    if @restaurant.update(restaurant_params)
      render json: restaurant_json(@restaurant)
    else
      render json: { errors: @restaurant.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # DELETE /restaurants/:id
  def destroy
    @restaurant.destroy
    head :no_content
  end

  # POST /restaurants/generate_restaurant
  def generate_restaurant
    begin
      city = params[:city]
      category = params[:category]
      price_level = params[:price]&.to_i
      save_to_db = ActiveModel::Type::Boolean.new.cast(params[:save])

      return render json: { error: "City parameter is required" }, status: :bad_request unless city.present?

      # Fetch restaurants from Google
      places_service = GooglePlacesService.new
      real_restaurants = places_service.fetch_restaurants(
        city: city,
        category: category,
        price_level: price_level,
        limit: 10
      ) rescue []

      real_restaurants.uniq! { |r| [r[:name].to_s.downcase.strip, r[:address].to_s.downcase.strip] }
      real_restaurants.shuffle!

      if real_restaurants.empty?
        return render json: { error: "No restaurants found for the given parameters" }, status: :not_found
      end

      # Pick a restaurant that doesn't exist yet
      selected_restaurant = real_restaurants.find { |r| !Restaurant.exists?(name: r[:name]) }
      return render json: { error: "All returned restaurants already exist in database" }, status: :conflict unless selected_restaurant

      openai = OpenAI::Client.new(access_token: ENV['OPENAI_API_KEY'])

      # Generate description
      description_prompt = <<~PROMPT
        Write a vivid 3–5 sentence description for a restaurant named "#{selected_restaurant[:name]}".
        City: #{city}.
        Category: #{category || selected_restaurant[:category] || 'Restaurant'}.
        Price level: #{selected_restaurant[:price] || price_level}.
        Include details about the food, atmosphere, and vibe.
        Output only valid JSON like: {"description": "..."}
      PROMPT

      response = openai.chat(
        parameters: {
          model: "gpt-4o-mini",
          messages: [
            { role: "system", content: "You generate realistic restaurant descriptions. Output valid JSON only." },
            { role: "user", content: description_prompt }
          ],
          temperature: 0.7
        }
      )

      ai_data = JSON.parse(response.dig("choices", 0, "message", "content") || "{}") rescue {}
      ai_description = ai_data["description"] || "A popular restaurant in #{city} serving delicious #{category || 'food'}."

      # 0–10 rating
      rating = selected_restaurant[:rating].to_f > 0 ? [[selected_restaurant[:rating].to_f * 2, 10.0].min, 0.0].max : rand(60..100)/10.0
      rating += [-0.5, -0.3, 0, 0.3, 0.5].sample
      rating = [[rating, 10.0].min, 0.0].max.round(1)

      final_restaurant = {
        name: selected_restaurant[:name],
        address: selected_restaurant[:address],
        city: city,
        state: "IL",
        zip_code: nil,
        rating: rating,
        price: selected_restaurant[:price],
        latitude: selected_restaurant[:latitude],
        longitude: selected_restaurant[:longitude],
        category: category || "Restaurant",
        food_type: category || "Various",
        description: ai_description,
        delivery_option: false,
        vegan_friendly: false,
        kid_friendly: false,
        parking: "Street",
        opening_hours: nil,
        website: nil,
        email: nil
      }

      if save_to_db
        restaurant = Restaurant.create!(final_restaurant)

        # Generate image and attach
        begin
          image_prompt = "A high-quality photo of #{restaurant.name}, a #{restaurant.category} in #{city}"
          image_resp = openai.images.generate(parameters: { prompt: image_prompt, size: "512x512" })
          image_url = image_resp.dig("data", 0, "url")
          if image_url
            downloaded_image = URI.open(image_url)
            restaurant.images.attach(io: downloaded_image, filename: "#{restaurant.name.parameterize}.png")
          end
        rescue => img_err
          Rails.logger.error "Image generation failed for #{restaurant.name}: #{img_err.message}"
        end

        render json: restaurant_json(restaurant), status: :created
      else
        render json: final_restaurant
      end

    rescue => e
      Rails.logger.error "generate_restaurant failed: #{e.message}\n#{e.backtrace.join("\n")}"
      render json: { error: e.message }, status: 500
    end
  end

  private

  def set_restaurant
    @restaurant = Restaurant.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Restaurant not found' }, status: :not_found
  end

  def restaurant_params
    params.require(:restaurant).permit(
      :name, :price, :rating, :food_type, :category,
      :description, :phone_number, :website, :email,
      :address, :city, :state, :zip_code,
      :latitude, :longitude, :opening_hours,
      :delivery_option, :vegan_friendly, :kid_friendly, :parking
    )
  end

  def restaurant_json(restaurant)
    {
      id: restaurant.id,
      name: restaurant.name,
      price: restaurant.price,
      rating: restaurant.rating,
      food_type: restaurant.food_type,
      category: restaurant.category,
      description: restaurant.description,
      phone_number: restaurant.phone_number,
      website: restaurant.website,
      email: restaurant.email,
      address: restaurant.address,
      city: restaurant.city,
      state: restaurant.state,
      zip_code: restaurant.zip_code,
      latitude: restaurant.latitude,
      longitude: restaurant.longitude,
      opening_hours: restaurant.opening_hours,
      delivery_option: restaurant.delivery_option,
      vegan_friendly: restaurant.vegan_friendly,
      kid_friendly: restaurant.kid_friendly,
      parking: restaurant.parking,
      created_at: restaurant.created_at,
      updated_at: restaurant.updated_at,
      images: restaurant.images.map do |img|
        Rails.application.routes.url_helpers.rails_blob_url(img, host: request.base_url)
      end
    }
  end
end
