class Client < ApplicationRecord
  enum :client_type, { b2c: 0, b2b: 1, hybrid: 2 }

  has_many :orders, dependent: :destroy
  has_many :users, dependent: :destroy

  validates :name, presence: true
end
