class RatingsController < ApplicationController
  skip_before_action :verify_authenticity_token

  def create
    user = User.find_by(id: params[:user_id])
    return render json: { error: "User not found" }, status: :not_found unless user

    recipe = Recipe.find(params[:recipe_id])
    rating = recipe.ratings.find_or_initialize_by(user: user)
    rating.value = params[:value] || params.dig(:rating, :value)

    if rating.save
      render json: { 
        message: "Rating saved successfully",
        average_rating: recipe.average_rating,
        user_rating: rating.value
      }, status: :ok
    else
      render json: { errors: rating.errors.full_messages }, status: :unprocessable_content
    end
  end

  def index
    recipe = Recipe.find(params[:recipe_id])
    render json: { average_rating: recipe.average_rating }
  end
end
