class RecipesController < ApplicationController

  def index 
    @recipes = Recipe.all
    render :index
  end

  def show
    @recipe = Recipe.find_by(id: params[:id])

    if @recipe 
      render :show
    else 
      render json: {message: 'The recipe doesnt exist'}
    end
  end

  def create 
    @recipe = Recipe.new(
      user_id: params[:user_id], 
      title: params[:title], 
      prep_time: params[:prep_time], 
      cook_time: params[:cook_time], 
      servings: params[:servings], 
      difficulty: params[:difficulty], 
      tags: params[:tags], 
      category: params[:category], 
      rating: params[:rating], 
      description: params[:description], 
      ingredients: params[:ingredients]
    )   
    if params[:images].present?
      @recipe.images.attach(params[:images])
    end

    if @recipe.save
      render json: { message: "Recipe created successfully", recipe: @recipe }, status: :created
    else
      render json: { errors: @recipe.errors.full_messages }, status: :unprocessable_entity
    end
  end  


  def update
    @recipe = Recipe.find_by(id: params[:id])
    if @recipe.nil?
      render json: { error: "Recipe not found" }, status: :not_found
      return
    end

    if @recipe.update(
      title: params[:title] || @recipe.title,
      prep_time: params[:prep_time] || @recipe.prep_time,
      cook_time: params[:cook_time] || @recipe.cook_time,
      servings: params[:servings] || @recipe.servings,
      difficulty: params[:difficulty] || @recipe.difficulty,
      tags: params[:tags] || @recipe.tags,
      category: params[:category] || @recipe.category,
      rating: params[:rating] || @recipe.rating,
      description: params[:description] || @recipe.description,
      ingredients: params[:ingredients] || @recipe.ingredients
    )
      # Replace images if new ones are provided
      if params[:images].present?
        @recipe.images.purge # remove old ones
        @recipe.images.attach(params[:images])
      end

      render json: { message: "Recipe updated successfully", recipe: @recipe }, status: :ok
    else
      render json: { errors: @recipe.errors.full_messages }, status: :unprocessable_entity
    end
  end


  def destroy
    @recipe = Recipe.find_by(id: params[:id])
    if @recipe.nil?
      render json: { error: "Recipe not found" }, status: :not_found
    else
      @recipe.destroy
      render json: { message: "Recipe deleted successfully" }, status: :ok
    end
  end
  
end


