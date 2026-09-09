class AddSoldAmountToProjects < ActiveRecord::Migration[8.0]
  def change
    add_column :projects, :sold_amount, :decimal, precision: 12, scale: 2
    add_column :projects, :sold_currency, :string
  end
end
