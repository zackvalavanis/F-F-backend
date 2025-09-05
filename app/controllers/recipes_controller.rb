class RecipesController < ApplicationController

  def index 
    @recipes = Recipe.all
    render :index
  end
end
