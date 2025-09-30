require 'openai'
require 'json'

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
    @recipe = Recipe.new(normalize_recipe(params.to_unsafe_h, category: params[:category], user_id: 1))

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
      ingredients: params[:ingredients] || @recipe.ingredients, 
      directions: params[:directions] || @recipe.directions
    )
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

    prompt = build_recipe_prompt(ingredients, diet: diet, servings: servings, category: category)
    openai = OpenaiService.new

    raw = begin
      openai.chat_system_user(prompt[:system], prompt[:user], model: "gpt-4o-mini", temperature: 0.2, max_tokens: 800)
    rescue => e
      Rails.logger.error("OpenAI client error: #{e.class} #{e.message}")
      return render json: { error: "LLM request failed." }, status: :bad_gateway
    end

    parsed = extract_json_from_text(raw)

    if parsed.nil?
      Rails.logger.info("Initial parse failed, retrying with stricter JSON-only instruction")
      retry_prompt_user = "ONLY output valid JSON (no explanation). #{prompt[:user]}"
      begin
        raw2 = openai.chat_system_user(prompt[:system], retry_prompt_user, model: "gpt-4o-mini", temperature: 0.0, max_tokens: 800)
        parsed = extract_json_from_text(raw2)
      rescue => e
        Rails.logger.error("OpenAI retry error: #{e.class} #{e.message}")
      end
    end

    unless parsed
      return render json: { error: "Could not parse recipe JSON from LLM response", raw: raw }, status: :unprocessable_entity
    end

    # Normalize AI response to match `create` structure
    recipe_attrs = normalize_recipe(parsed, category: category, user_id: 1)

    if save_to_db
      new_recipe = Recipe.new(recipe_attrs)
      if new_recipe.save
        render json: { message: "AI recipe created", recipe: recipe_with_images(new_recipe) }, status: :created
      else
        Rails.logger.error("Failed to save recipe: #{new_recipe.errors.full_messages}")
        render json: { error: "Failed to save recipe", details: new_recipe.errors.full_messages }, status: :unprocessable_entity
      end
    else
      render json: { generated: parsed, normalized: recipe_attrs }, status: :ok
    end
  end

  private

  # Normalize a recipe hash to the structure used in `create`
  def normalize_recipe(source, category: nil, user_id: 1)
    # Ingredients as array
    ingredients_list = (source["ingredients"] || source[:ingredients] || []).map do |i|
      if i.is_a?(Hash)
        "#{i['quantity'] || ''} #{i['name']}".strip
      else
        i.to_s.strip
      end
    end.join(", ")
  
    # Directions as array
    directions_list = (source["steps"] || source[:directions] || []).map(&:strip)
  
    # Tags as comma-separated string
    tags_text = (source["tags"] || source[:tags] || []).join(", ")
  
    # Capitalize category
    formatted_category = (category || source["category"] || source[:category] || "Uncategorized").to_s.capitalize
  
    {
      user_id: user_id,
      title: source["title"] || source[:title] || "AI-generated recipe",
      prep_time: (source["prep_minutes"] || source[:prep_time] || 10).to_i,
      cook_time: (source["cook_minutes"] || source["total_minutes"] || source[:cook_time] || 10).to_i,
      servings: (source["servings"] || source[:servings] || 1).to_i,
      difficulty: (source["difficulty"] || 1).to_i,
      rating: (source["rating"] || 1).to_i,
      tags: tags_text,
      category: formatted_category,
      description: source["description"].presence || source["notes"].presence || "A delicious dish created with your ingredients.",
      ingredients: ingredients_list,    # <-- array
      directions: directions_list.join(". ").strip       # <-- array
    }
  end
  
  
  # Build system + user prompt for AI
  def build_recipe_prompt(ingredients, diet: nil, servings: nil, category: nil)
    schema = {
      "title" => "string",
      "category" => "string",
      "servings" => "number or null",
      "total_minutes" => "number or null",
      "ingredients" => [{"name"=>"string", "quantity"=>"string or null", "notes"=>"string or null"}],
      "steps" => ["string"],
      "tags" => ["string"],
      "substitutions" => [{"ingredient"=>"string", "suggestions"=>["string"]}],
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

    user = "Ingredients: [" + ingredients.map(&:to_s).join(", ") + "]."
    user += " Dietary preference: #{diet}." if diet.present?
    user += " Target servings: #{servings}." if servings.present?
    user += " Category: #{category}." if category.present?
    user += " Build a recipe using those ingredients where possible. Output JSON only."

    { system: system, user: user }
  end

  # Extract JSON from raw AI text
  def extract_json_from_text(text)
    return nil unless text.is_a?(String)

    first = text.index("{")
    last = text.rindex("}")
    return nil unless first && last && last > first

    candidate = text[first..last]
    begin
      JSON.parse(candidate)
    rescue JSON::ParserError
      fixed = candidate.gsub("=>", ":").gsub(/([\w-]+):\s*(\w+)/, '"\1": "\2"')
      begin
        JSON.parse(fixed)
      rescue JSON::ParserError
        nil
      end
    end
  end

  # Attach images to a recipe
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
