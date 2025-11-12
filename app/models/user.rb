class User < ApplicationRecord
  has_secure_password
  validates :email, presence: true, uniqueness: true
  has_many :recipes
  has_many :ratings, dependent: :destroy
  has_many :rated_recipes, through: :ratings, source: :recipe
  has_many :restaurants
end
