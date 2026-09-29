class PromoteRetainerBillingTreatment < ActiveRecord::Migration[8.0]
  def up
    execute <<~SQL.squish
      UPDATE time_entries
      SET billing_treatment = 'retainer'
      WHERE billing_treatment = 'included_maintenance'
        AND project_id IN (
          SELECT id FROM projects WHERE monthly_retainer_hours > 0
        )
    SQL

    execute <<~SQL.squish
      UPDATE projects
      SET billing_treatment = 'retainer'
      WHERE monthly_retainer_hours > 0
    SQL
  end

  def down
    execute "UPDATE time_entries SET billing_treatment = 'included_maintenance' WHERE billing_treatment = 'retainer'"
    execute "UPDATE projects SET billing_treatment = 'included_maintenance' WHERE billing_treatment = 'retainer'"
  end
end
