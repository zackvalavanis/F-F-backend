class RecipesController < ApplicationController
  include Rails.application.routes.url_helpers
  skip_before_action :verify_authenticity_token

  # Helper method to serialize a recipe with image URLs
  def recipe_with_images(recipe)
    recipe.as_json.merge(
      images: recipe.images.map { |img| url_for(img) },
      user: recipe.user.present? ? { id: recipe.user.id, name: recipe.user.name, email: recipe.user.email } : nil
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
      user_id: 1,
      title: params[:title],
      prep_time: params[:prep_time].to_i,
      cook_time: params[:cook_time].to_i,
      servings: params[:servings].to_i,
      difficulty: params[:difficulty].to_i,
      tags: params[:tags],
      category: params[:category],
      rating: params[:rating].to_i,
      description: params[:description],
      ingredients: params[:ingredients]
    )

    if @recipe.save
      attach_images(@recipe)
      render json: { message: "Recipe created successfully", recipe: recipe_with_images(@recipe) }, status: :created
    else
      render json: { errors: @recipe.errors.full_messages }, status: :unprocessable_content
    end
  end

  # PATCH/PUT /recipes/:id
  def update
    @recipe = Recipe.find_by(id: params[:id])
    return render json: { error: "Recipe not found" }, status: :not_found unless @recipe

    if @recipe.update(
      title: params[:title] || @recipe.title,
      prep_time: params[:prep_time]&.to_i || @recipe.prep_time,
      cook_time: params[:cook_time]&.to_i || @recipe.cook_time,
      servings: params[:servings]&.to_i || @recipe.servings,
      difficulty: params[:difficulty]&.to_i || @recipe.difficulty,
      rating: params[:rating]&.to_i || @recipe.rating,
      tags: params[:tags] || @recipe.tags,
      category: params[:category] || @recipe.category,
      description: params[:description] || @recipe.description,
      ingredients: params[:ingredients] || @recipe.ingredients
    )
      # Replace images if new ones are provided
      attach_images(@recipe, replace: true)
      render json: { message: "Recipe updated successfully", recipe: recipe_with_images(@recipe) }, status: :ok
    else
      render json: { errors: @recipe.errors.full_messages }, status: :unprocessable_content
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
