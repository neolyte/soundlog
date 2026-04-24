class AddActiveToClients < ActiveRecord::Migration[8.0]
  def change
    add_column :clients, :active, :boolean, default: true, null: false
    add_index :clients, :active
  end
end
