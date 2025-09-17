class RecipesController < ApplicationController
  include Rails.application.routes.url_helpers
  skip_before_action :verify_authenticity_token

  # Helper method to serialize a recipe with image URLs
  def recipe_with_images(recipe)
    recipe.as_json.merge(
      images: recipe.images.map { |img| url_for(img) }
    )
  end

  # GET /recipes
  def index
    @recipes = Recipe.all
    render json: @recipes.map { |recipe| recipe_with_images(recipe) }
  end

  # GET /recipes/:id
  def show
    @recipe = Recipe.find_by(id: params[:id])
    if @recipe
      render json: recipe_with_images(@recipe)
    else
      render json: { message: 'The recipe does not exist' }, status: :not_found
    end
  end

  # POST /recipes
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

    if @recipe.save
      attach_images(@recipe)
      render json: { message: "Recipe created successfully", recipe: recipe_with_images(@recipe) }, status: :created
    else
      render json: { errors: @recipe.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /recipes/:id
  def update
    @recipe = Recipe.find_by(id: params[:id])
    return render json: { error: "Recipe not found" }, status: :not_found unless @recipe

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
      attach_images(@recipe, replace: true)
      render json: { message: "Recipe updated successfully", recipe: recipe_with_images(@recipe) }, status: :ok
    else
      render json: { errors: @recipe.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # DELETE /recipes/:id
  def destroy
    @recipe = Recipe.find_by(id: params[:id])
    if @recipe.nil?
      render json: { error: "Recipe not found" }, status: :not_found
    else
      @recipe.destroy
      render json: { message: "Recipe deleted successfully" }, status: :ok
    end
  end

  private 

  # Handles attaching images with correct content type
  def attach_images(recipe, replace: false)
    return unless params[:images].present?

    recipe.images.purge if replace

    # Support multiple image uploads
    images = params[:images].is_a?(Array) ? params[:images] : [params[:images]]
    images.each do |img|
      recipe.images.attach(
        io: img.tempfile,
        filename: img.original_filename,
        content_type: img.content_type
      )
    end
  end
end
