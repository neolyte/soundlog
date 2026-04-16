class AddServiceNameAndStatusToTimeEntries < ActiveRecord::Migration[8.0]
  def change
    add_column :time_entries, :service_name, :string
    add_column :time_entries, :status, :string
  end
end
