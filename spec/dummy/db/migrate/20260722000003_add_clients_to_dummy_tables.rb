class AddClientsToDummyTables < ActiveRecord::Migration[8.0]
  def change
    unless table_exists?(:clients)
      create_table :clients do |t|
        t.string :name, null: false

        t.timestamps
      end
    end

    unless column_exists?(:orders, :client_id)
      add_reference :orders, :client, foreign_key: true
    end

    unless column_exists?(:users, :client_id)
      add_reference :users, :client, foreign_key: true
    end
  end
end
