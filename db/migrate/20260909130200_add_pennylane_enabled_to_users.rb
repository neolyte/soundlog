class AddPennylaneEnabledToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :pennylane_enabled, :boolean, default: false, null: false
  end
end
