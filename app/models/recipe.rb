class Recipe < ApplicationRecord
  belongs_to :user

  has_many_attached :images 

  validates :title, :ingredients, :description, presence: true
end
