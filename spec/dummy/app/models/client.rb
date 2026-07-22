class Client < ApplicationRecord
  has_many :orders, dependent: :destroy
  has_many :users, dependent: :destroy

  validates :name, presence: true
end
