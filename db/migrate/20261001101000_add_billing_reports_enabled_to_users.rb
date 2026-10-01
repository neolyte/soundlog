class AddBillingReportsEnabledToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :billing_reports_enabled, :boolean, default: true, null: false
  end
end
