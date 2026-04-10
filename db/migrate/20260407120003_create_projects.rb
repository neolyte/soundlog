class CreateProjects < ActiveRecord::Migration[8.0]
  def change
    create_table :projects do |t|
      t.string :name, null: false
      t.text :description
      t.references :user, null: false, foreign_key: true
      t.references :client, null: false, foreign_key: true
      t.boolean :active, default: true

      t.timestamps
    end

    add_index :projects, [:user_id, :client_id]
  end
end
