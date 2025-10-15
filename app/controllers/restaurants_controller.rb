class RestaurantsController < ApplicationController
    before_action :set_restaurant, only: [:show, :update, :destroy]
  
    # GET /restaurants
    def index
      @restaurants = Restaurant.all
  
      Rails.application.routes.default_url_options[:host] = "localhost:3000"

      # Optional filtering by price, rating, city, food_type
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
  
    private
  
    # Use callbacks to share common setup or constraints between actions.
    def set_restaurant
      @restaurant = Restaurant.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      render json: { error: 'Restaurant not found' }, status: :not_found
    end
  
    # Only allow a list of trusted parameters through.
    def restaurant_params
      params.require(:restaurant).permit(
        :name, :price, :rating, :food_type, :category,
        :description, :phone_number, :website, :email,
        :address, :city, :state, :zip_code,
        :latitude, :longitude, :opening_hours,
        :delivery_option, :vegan_friendly, :kid_friendly, :parking
      )
    end
end
