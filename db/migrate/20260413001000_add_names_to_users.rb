class AddNamesToUsers < ActiveRecord::Migration[8.0]
  class MigrationUser < ApplicationRecord
    self.table_name = "users"
  end

  def up
    add_column :users, :first_name, :string
    add_column :users, :last_name, :string

    MigrationUser.reset_column_information

    MigrationUser.find_each do |user|
      first_name, last_name = inferred_names_for(user.email)
      user.update_columns(first_name:, last_name:)
    end

    change_column_null :users, :first_name, false
    change_column_null :users, :last_name, false
  end

  def down
    remove_column :users, :first_name
    remove_column :users, :last_name
  end

  private

  def inferred_names_for(email)
    local_part = email.to_s.split("@").first.to_s
    parts = local_part.split(/[._-]+/).reject(&:blank?)

    if parts.length >= 2
      [parts.first.capitalize, parts.last.capitalize]
    elsif parts.first.present?
      [parts.first.capitalize, "User"]
    else
      ["Unknown", "User"]
    end
  end
end
