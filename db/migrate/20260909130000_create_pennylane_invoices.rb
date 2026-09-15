class CreatePennylaneInvoices < ActiveRecord::Migration[8.0]
  def change
    create_table :pennylane_invoices do |t|
      t.string :remote_id, null: false
      t.string :number
      t.datetime :last_synced_at
      t.timestamps
    end

    add_index :pennylane_invoices, :remote_id, unique: true
  end
end
