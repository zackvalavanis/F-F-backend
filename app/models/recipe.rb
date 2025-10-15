class Recipe < ApplicationRecord
  belongs_to :user

  has_many_attached :images
  has_many :ratings, dependent: :destroy
  has_many :rated_users, through: :ratings, source: :user

  def average_rating
    ratings.average(:value)&.round(2)
  end

  validates :title, :category, :description, :ingredients, presence: true
  validates :prep_time, :cook_time, :difficulty, :servings,
            numericality: { only_integer: true, greater_than: 0 }
end
