class BackfillProjectRetainerPeriodsFromDefaults < ActiveRecord::Migration[8.0]
  START_MONTH = Date.new(2026, 1, 1)
  END_MONTH = Date.new(2026, 10, 1)
  BACKFILL_NOTE = "Backfilled from project default".freeze

  class MigrationProject < ActiveRecord::Base
    self.table_name = "projects"
  end

  class MigrationProjectRetainerPeriod < ActiveRecord::Base
    self.table_name = "project_retainer_periods"
  end

  def up
    months = months_to_backfill

    MigrationProject
      .where(billing_treatment: "retainer")
      .where.not(monthly_retainer_hours: nil)
      .find_each do |project|
        next unless project.monthly_retainer_hours.positive?

        months.each do |month|
          MigrationProjectRetainerPeriod.find_or_create_by!(project_id: project.id, month:) do |period|
            period.retainer_hours = project.monthly_retainer_hours
            period.note = BACKFILL_NOTE
          end
        end
      end
  end

  def down
    MigrationProjectRetainerPeriod
      .where(month: START_MONTH..END_MONTH, note: BACKFILL_NOTE)
      .delete_all
  end

  private

  def months_to_backfill
    month = START_MONTH
    months = []

    while month <= END_MONTH
      months << month
      month = month.next_month
    end

    months
  end
end
