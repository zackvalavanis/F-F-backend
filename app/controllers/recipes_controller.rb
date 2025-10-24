require 'openai'
require 'open-uri'
require 'json'

class RecipesController < ApplicationController
  include Rails.application.routes.url_helpers
  skip_before_action :verify_authenticity_token

  # Serialize a recipe with image URLs, user info, and average rating
  def recipe_with_images(recipe)
    recipe.as_json.merge(
      images: recipe.images.map { |img| url_for(img) },
      user: recipe.user.present? ? {
        id: recipe.user.id,
        name: recipe.user.name,
        email: recipe.user.email
      } : nil,
      average_rating: recipe.average_rating
    )
  end

  # GET /recipes
  def index
    recipes = Recipe.includes(:user, :ratings, images_attachments: :blob)
    render json: recipes.map { |r| recipe_with_images(r) }
  end

  # GET /recipes/:id
  def show
    recipe = Recipe.find_by(id: params[:id])
    if recipe
      render json: recipe_with_images(recipe)
    else
      render json: { error: 'Recipe not found' }, status: :not_found
    end
  end

  # POST /recipes
  def create
    recipe_attrs = normalize_recipe(params.to_unsafe_h, category: params[:category], user_id: params[:user_id])
    recipe = Recipe.new(recipe_attrs)

    if recipe.save
      attach_images(recipe)
      render json: { message: 'Recipe created successfully', recipe: recipe_with_images(recipe) }, status: :created
    else
      render json: { errors: recipe.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /recipes/:id
  def update
    recipe = Recipe.find_by(id: params[:id])
    return render json: { error: 'Recipe not found' }, status: :not_found unless recipe

    if recipe.update(
      title: params[:title] || recipe.title,
      prep_time: params[:prep_time]&.to_i || recipe.prep_time,
      cook_time: params[:cook_time]&.to_i || recipe.cook_time,
      servings: params[:servings]&.to_i || recipe.servings,
      difficulty: params[:difficulty]&.to_i || recipe.difficulty,
      tags: params[:tags] || recipe.tags,
      category: params[:category] || recipe.category,
      description: params[:description] || recipe.description,
      ingredients: params[:ingredients] || recipe.ingredients,
      directions: params[:directions] || recipe.directions
    )
      attach_images(recipe, replace: true)
      render json: { message: 'Recipe updated successfully', recipe: recipe_with_images(recipe) }, status: :ok
    else
      render json: { errors: recipe.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # DELETE /recipes/:id
  def destroy
    recipe = Recipe.find_by(id: params[:id])
    return render json: { error: 'Recipe not found' }, status: :not_found unless recipe

    recipe.destroy
    render json: { message: 'Recipe deleted successfully' }, status: :ok
  end

  # POST /recipes/:id/rate
  def rate
    recipe = Recipe.find_by(id: params[:id])
    return render json: { error: 'Recipe not found' }, status: :not_found unless recipe

    user = current_user
    rating_value = params[:value].to_i.clamp(1, 10)
    rating = Rating.find_or_initialize_by(user: user, recipe: recipe)
    rating.value = rating_value

    if rating.save
      render json: {
        message: 'Rating saved successfully',
        average_rating: recipe.average_rating,
        user_rating: rating_value
      }, status: :ok
    else
      render json: { errors: rating.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # AI recipe generation
  def generate_from_ingredients
    ingredients = params[:ingredients]
    category = params[:category]
    allowed_categories = %w[breakfast lunch dinner dessert]
    category = allowed_categories.include?(category&.downcase) ? category.downcase : nil

    unless ingredients.is_a?(Array) && ingredients.any?
      return render json: { error: 'Provide an ingredients array in the request body' }, status: :bad_request
    end

    diet = params[:diet]
    servings = params[:servings].to_i
    save_to_db = ActiveModel::Type::Boolean.new.cast(params[:save])

    Rails.logger.info("Received user_id param: #{params[:user_id]}")

    prompt = build_recipe_prompt(ingredients, diet: diet, servings: servings, category: category)
    openai = OpenaiService.new
    raw = openai.chat_system_user(prompt[:system], prompt[:user], model: "gpt-4o-mini", temperature: 0.2, max_tokens: 800)
    parsed = extract_json_from_text(raw)

    unless parsed
      retry_prompt_user = "ONLY output valid JSON (no explanation). #{prompt[:user]}"
      raw2 = openai.chat_system_user(prompt[:system], retry_prompt_user, model: "gpt-4o-mini", temperature: 0.0, max_tokens: 800)
      parsed = extract_json_from_text(raw2)
    end

    unless parsed
      return render json: { error: 'Could not parse recipe JSON from LLM response', raw: raw }, status: :unprocessable_entity
    end

    user_id = params[:user_id].to_i
    user_id = current_user.id if user_id.zero? && current_user.present?
    recipe_attrs = normalize_recipe(parsed, category: category, user_id: user_id)

    if save_to_db
      new_recipe = Recipe.new(recipe_attrs)
      if new_recipe.save
        generate_recipe_image(new_recipe)
        render json: { message: 'AI recipe created', recipe: recipe_with_images(new_recipe) }, status: :created
      else
        render json: { error: 'Failed to save recipe', details: new_recipe.errors.full_messages }, status: :unprocessable_entity
      end
    else
      render json: { generated: parsed, normalized: recipe_attrs }, status: :ok
    end
  end

  private

  def normalize_recipe(source, category: nil, user_id:)
    # Ingredients
    ingredients_array = case source["ingredients"]
                        when String
                          [source["ingredients"]].reject(&:blank?) # wrap string in array
                        when Array
                          source["ingredients"]
                        else
                          []
                        end
  
    # Directions
    directions_array = case source["directions"]
    when String then [source["directions"]].reject(&:blank?)
    when Array then source["directions"]
    else
      # fallback to "steps" if "directions" is missing
      case source["steps"]
      when String then [source["steps"]].reject(&:blank?)
      when Array then source["steps"]
      else []
      end
    end
  
    # Tags
    tags_array = case source["tags"]
                 when String
                   source["tags"].split(",").map(&:strip).reject(&:blank?)
                 when Array
                   source["tags"]
                 else
                   []
                 end
  
    ingredients_list = ingredients_array.map do |i|
      i.is_a?(Hash) ? "#{i['quantity'] || ''} #{i['name']}".strip : i.to_s.strip
    end.join(", ")
  
    directions_list = directions_array.map(&:strip)
  
    formatted_category = category.present? ? category.capitalize : (source["category"] || "Uncategorized").to_s.capitalize
  
    {
      user_id: user_id,
      title: source["title"] || "AI-generated recipe",
      prep_time: (source["prep_time"] || 10).to_i,
      cook_time: (source["cook_time"] || 10).to_i,
      servings: (source["servings"] || 1).to_i,
      difficulty: (source["difficulty"] || 1).to_i,
      tags: tags_array.join(", "),
      category: formatted_category,
      description: source["description"].presence || "A delicious dish.",
      ingredients: ingredients_list,
      directions: directions_list.join(". ").strip
    }
  end
  
  
  

  # Build OpenAI recipe prompt
  def build_recipe_prompt(ingredients, diet: nil, servings: nil, category: nil)
    schema = {
      "title" => "string",
      "category" => "string",
      "servings" => "number or null",
      "total_minutes" => "number or null",
      "ingredients" => [{"name" => "string", "quantity" => "string or null"}],
      "steps" => ["string"],
      "tags" => ["string"],
      "notes" => "string or null"
    }
  
    system = <<~SYS
      You are a helpful chef assistant. Produce exactly one valid JSON object following this schema (no additional text):
      #{JSON.pretty_generate(schema)}
  
      - Use null for unknown numeric values.
      - If you can't determine a quantity, set it to null.
      - Keep steps short and numbered.
      - Prefer simple, achievable instructions.
    SYS
  
    user = "Ingredients: [#{ingredients.join(', ')}]."
    user += " Dietary preference: #{diet}." unless diet.nil? || diet.to_s.strip.empty?
    user += " Target servings: #{servings}." if servings.to_i > 0
    user += " Category: #{category}." unless category.nil? || category.to_s.strip.empty?
    user += " Build a recipe using those ingredients where possible. Output JSON only."
  
    { system: system, user: user }
  end
  

  # Safely extract JSON from a string
  def extract_json_from_text(text)
    return nil unless text.is_a?(String)
    first = text.index("{")
    last = text.rindex("}")
    return nil unless first && last && last > first

    candidate = text[first..last]
    JSON.parse(candidate)
  rescue JSON::ParserError
    nil
  end

  # Generate an image for a recipe using OpenAI
  def generate_recipe_image(recipe)
    prompt = "A plate of #{recipe.title} with ingredients: #{recipe.ingredients}. Professional food photography style."
    image_url = OpenaiService.new.generate_image(prompt, size: "512x512")
    return unless image_url

    file = URI.open(image_url)
    recipe.images.attach(io: file, filename: "#{recipe.title.parameterize}.png", content_type: 'image/png')
  end

  # Attach uploaded images to recipe
  def attach_images(recipe, replace: false)
    return unless params[:images].present?

    recipe.images.purge if replace
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
