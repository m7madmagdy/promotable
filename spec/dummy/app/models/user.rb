class User < ApplicationRecord
  acts_as_promoter

  validates :name, presence: true
end
