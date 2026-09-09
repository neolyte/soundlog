class CreateProjectPennylaneInvoices < ActiveRecord::Migration[8.0]
  def change
    create_table :project_pennylane_invoices do |t|
      t.references :project, null: false, foreign_key: true
      t.references :pennylane_invoice, null: false, foreign_key: true
      t.timestamps
    end

    add_index :project_pennylane_invoices, [:project_id, :pennylane_invoice_id], unique: true, name: "index_project_pennylane_invoices_on_project_and_invoice"
  end
end
