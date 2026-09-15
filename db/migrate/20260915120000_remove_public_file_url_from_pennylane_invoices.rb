class RemovePublicFileUrlFromPennylaneInvoices < ActiveRecord::Migration[8.0]
  def up
    remove_column :pennylane_invoices, :public_file_url, :string, if_exists: true
  end

  def down
    add_column :pennylane_invoices, :public_file_url, :string unless column_exists?(:pennylane_invoices, :public_file_url)
  end
end
