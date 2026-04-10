class CreateTimeEntries < ActiveRecord::Migration[8.0]
  def change
    create_table :time_entries do |t|
      t.references :user, null: false, foreign_key: true
      t.references :project, null: false, foreign_key: true
      t.date :date, null: false
      t.decimal :hours, precision: 8, scale: 2, null: false
      t.text :description

      t.timestamps
    end

    add_index :time_entries, [:user_id, :date]
    add_index :time_entries, [:project_id, :date]
  end
end
