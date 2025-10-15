class RatingsController < ApplicationController
 
  def create
    recipe = Recipe.find(params[:recipe_id])
    rating = recipe.ratings.find_or_initialize_by(user: current_user)
    rating.value = params[:value]

    if rating.save
      render json: { 
        message: "Rating saved successfully",
        average_rating: recipe.average_rating,
        user_rating: rating.value
      }, status: :ok
    else
      render json: { errors: rating.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def index
    recipe = Recipe.find(params[:recipe_id])
    render json: { average_rating: recipe.average_rating }
  end
end

