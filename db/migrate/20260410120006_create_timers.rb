class CreateTimers < ActiveRecord::Migration[8.0]
  def change
    create_table :timers do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.references :project, null: true, foreign_key: true
      t.text :description
      t.string :state, null: false, default: "running"
      t.datetime :started_at
      t.integer :accumulated_seconds, null: false, default: 0

      t.timestamps
    end
  end
end
