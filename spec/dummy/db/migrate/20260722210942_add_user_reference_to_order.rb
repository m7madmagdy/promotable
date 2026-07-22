class AddUserReferenceToOrder < ActiveRecord::Migration[8.1]
  def change
    unless column_exists?(:orders, :user_id)
      add_reference :orders, :user, foreign_key: true
    end
  end
end
