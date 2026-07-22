class User < ApplicationRecord
  acts_as_promoter

  belongs_to :client, optional: false
  has_many :orders, dependent: :destroy

  validates :name, presence: true
end
