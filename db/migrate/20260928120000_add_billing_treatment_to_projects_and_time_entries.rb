class AddBillingTreatmentToProjectsAndTimeEntries < ActiveRecord::Migration[8.0]
  def change
    add_column :projects, :billing_treatment, :string, null: false, default: "invoiceable"
    add_column :projects, :hourly_rate, :decimal, precision: 10, scale: 2
    add_column :projects, :hourly_rate_currency, :string
    add_column :time_entries, :billing_treatment, :string

    add_index :projects, :billing_treatment
    add_index :time_entries, :billing_treatment

    reversible do |dir|
      dir.up do
        execute "UPDATE projects SET billing_treatment = 'not_charged' WHERE billable = 0"
      end
    end
  end
end
