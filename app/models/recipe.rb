class Recipe < ApplicationRecord
  belongs_to :user

  has_many_attached :images

  validates :title, :category, :description, :ingredients, presence: true
  validates :prep_time, :cook_time, :difficulty, :rating, :servings,
            numericality: { only_integer: true, greater_than: 0 }
end
