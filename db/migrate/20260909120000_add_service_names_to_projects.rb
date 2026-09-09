class AddServiceNamesToProjects < ActiveRecord::Migration[8.0]
  def change
    add_column :projects, :service_names, :text
  end
end
