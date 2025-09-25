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
    @recipe = Recipe.new(
      user_id: 1,
      title: params[:title],
      prep_time: params[:prep_time].to_i,
      cook_time: params[:cook_time].to_i,
      servings: params[:servings]&.to_i,
      difficulty: params[:difficulty].to_i,
      tags: params[:tags],
      category: params[:category],
      rating: params[:rating].to_i,
      description: params[:description],
      ingredients: params[:ingredients],
      directions: params[:directions]
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
      ingredients: params[:ingredients] || @recipe.ingredients, 
      directions: params[:directions] || @recipe.directions
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




  # ai generation of recipe
  def generate_from_ingredients 
    ingredients = params[:ingredients]
    unless ingredients.is_a?(Array) && ingredients.any? 
      return render json: { error: 'Provide an ingredients array in the request body'}, status: :bad_request
    end

    diet = params[:diet]
    servings = params[:servings].to_i
    save_to_db = Active::Type::Boolean.new.cast(params[:save])

    prompt = build_recipe_prompt(ingredients, diet: diet, servings: servings)

    begin 
      client = OpenAI::Client.new(access_token: ENV.fetch("OPEN_API_KEY"))
      response = client.chat(
        parameters: {
          model: "gpt-4o-mini",
          messages: [
            {role: 'system', content: prompt[:system]}, 
            {role: 'user', content: prompt[:user]}
          ], 
          temperature: 0.2,
          max_tokens: 800
        }
      )
    rescue => e
      Rails.logger.error("OpenAI client error; #{e.class} #{e.message}")
      return render json: { error: "LLM request failed."}, status: :bad_gateway
    end 

    raw = response.dig("choices", 0, "message", "content")
    parsed = extract_json_from_text(raw)

    if parsed.nil?
      Rails.logger.info("initial parse failed, retrying with stricter JSON-only instruction")
      retry_prompt = { 
        system: prompt[:system], 
        user: "ONLY output valid JSON (no explaination)." + prompt[:user]
      }

      begin 
        retry_resp = client.chat(
          parameters: {
            model: "gpt-4o-mini",
            messages: [
              { role: "system", content: retry_prompt[:system] },
              { role: "user", content: retry_prompt[:user] }
            ],
            temperature: 0.0,
            max_tokens: 800
          }
        )
        raw2 = retry_resp.dig("choices", 0, "message", "content")
        parsed = extract_json_from_text(raw2)
      rescue => e
        Rails.logger.error("OpenAI retry error: #{e.class} #{e.message}")
      end
    end

    unless parsed
      return render json: { error: "Could not parse recipe JSON from LLM response", raw: raw }, status: :unprocessable_entity
    end

    recipe_attrs = { 
      title: parsed["title"] || parsed[:title] || "AI-generated recipe",
      prep_time: parsed["prep_minutes"] || parsed["prep_minutes"] || 0,
      cook_time: parsed["cook_minutes"] || parsed["cook_minutes"] || parsed["total_minutes"] || 0,
      servings: parsed["servings"] || nil,
      tags: parsed["tags"] || [],
      category: parsed["category"] || nil,
      description: parsed["notes"] || parsed["description"] || nil,
      # store ingredients/directions in a simple text/array form depending on your schema
      ingredients: (parsed["ingredients"] || []).map { |i| "#{i['quantity'] || ''} #{i['name']}".strip },
      directions: parsed["steps"] || []
    }

    if save_to_db
      # You may want to set user properly; I left user_id: 1 like your create method
      new_recipe = Recipe.new(recipe_attrs.merge(user_id: 1))
      if new_recipe.save
        render json: { message: "AI recipe created", recipe: recipe_with_images(new_recipe) }, status: :created
      else
        render json: { error: "Failed to save recipe", details: new_recipe.errors.full_messages }, status: :unprocessable_entity
      end
    else
      # just return the parsed JSON (and the normalized attrs for convenience)
      render json: { generated: parsed, normalized: recipe_attrs }, status: :ok
    end
  end
  private


  # Creates a two-part prompt: system instructions & user input
  def build_recipe_prompt(ingredients, diet: nil, servings: nil)
    schema = {
      "title" => "string",
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
      - If multiple possible recipes exist, prefer simple, achievable instructions.
    SYS

    user = "Ingredients: [" + ingredients.map { |i| i.to_s }.join(", ") + "]."
    user += " Dietary preference: #{diet}." if diet.present?
    user += " Target servings: #{servings}." if servings.present?
    user += " Build a recipe using those ingredients where possible. Output JSON only."

    { system: system, user: user }
  end

  # Attempt to extract the first JSON object from a text blob
  def extract_json_from_text(text)
    return nil unless text.is_a?(String)

    first = text.index("{")
    last = text.rindex("}")
    return nil unless first && last && last > first

    candidate = text[first..last]
    begin
      JSON.parse(candidate)
    rescue JSON::ParserError
      # attempt quick fixes for common LLM formatting issues
      fixed = candidate.gsub("=>", ":").gsub(/([\w-]+):\s*(\w+)/, '"\1": "\2"') # conservative attempt
      begin
        JSON.parse(fixed)
      rescue JSON::ParserError
        nil
      end
    end
  end

  # unchanged image attach helper
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

