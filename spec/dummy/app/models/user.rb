class User < ApplicationRecord
  acts_as_promoter

  # Match hive's coupon contract: BirthdayRule reads #birthday.
  alias_attribute :birthday, :date_of_birth

  belongs_to :client, optional: false
  has_many :orders, dependent: :destroy

  validates :name, presence: true
end
