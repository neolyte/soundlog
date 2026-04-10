class AddTotalHoursToProjects < ActiveRecord::Migration[8.0]
  def change
    add_column :projects, :total_hours, :decimal, precision: 8, scale: 2
  end
end
