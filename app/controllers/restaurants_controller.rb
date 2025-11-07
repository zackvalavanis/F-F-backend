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

  # =============================
  # AI generate restaurant action
  # =============================
  def generate_restaurant
    city = params[:city]
    category = params[:category]
    price_level = params[:price]&.to_i
    save_to_db = ActiveModel::Type::Boolean.new.cast(params[:save])
  
    places_service = GooglePlacesService.new
    real_restaurants = places_service.fetch_restaurants(
      city: city,
      category: category,
      price_level: price_level
    )
  
    openai = OpenAI::Client.new(access_token: ENV['OPENAI_API_KEY'])
  
    # ✅ Add AI descriptions for each Google restaurant
    enriched_restaurants = real_restaurants.map do |r|
      begin
        prompt = build_restaurant_prompt(
          city: city,
          category: category || r[:category],
          price: r[:price],
          description: nil
        )
  
        response = openai.chat(
          parameters: {
            model: "gpt-4o-mini",
            messages: [
              { role: "system", content: prompt[:system] },
              { role: "user", content: prompt[:user] }
            ],
            temperature: 0.8
          }
        )
  
        ai_data = JSON.parse(response.dig("choices", 0, "message", "content")) rescue {}
        ai_description = ai_data["description"]
  
      rescue => e
        Rails.logger.error "AI description failed for #{r[:name]}: #{e.message}"
        ai_description = "A popular spot in #{city} serving delicious #{category || 'dishes'}."
      end
  
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
        description: ai_description, # ✅ now populated
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
  
        restaurant
      end
  
      render json: restaurants.map { |r| restaurant_json(r) }, status: :created 
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

  # JSON helper for restaurant
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

  # Build AI prompt
  def build_restaurant_prompt(city: nil, category: nil, price: nil, description: nil)
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
      You are a professional restauranteur. Produce exactly one valid JSON object following this schema (no additional text):
      #{JSON.pretty_generate(schema)}

     
      - The "description" field should be a rich, enticing 3–6 sentence paragraph describing the restaurant’s atmosphere, style, and cuisine.
      - Be specific and creative. Pretend you visited the restaurant.
      - Use null for unknown numeric values.
      - Boolean fields must be true or false.
      - Include realistic data for address, phone, and website if missing.
      - Do NOT include markdown, labels, or commentary — JSON only.
    SYS

    user_message = "Find a restaurant"
    user_message += " in city: #{city}" if city.present?
    user_message += " with category: #{category}" if category.present?
    user_message += " with price: #{price}" if price.present?
    user_message += ". Include a detailed, enticing description field."
    user_message += ". Return JSON only."

    { system: system_message, user: user_message }
  end
end
