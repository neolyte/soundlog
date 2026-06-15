class CreateProjectRetainerPeriods < ActiveRecord::Migration[8.0]
  def change
    create_table :project_retainer_periods do |t|
      t.references :project, null: false, foreign_key: true
      t.date :month, null: false
      t.decimal :retainer_hours, precision: 8, scale: 2, null: false
      t.text :note

      t.timestamps
    end

    add_index :project_retainer_periods, [:project_id, :month], unique: true
  end
end
