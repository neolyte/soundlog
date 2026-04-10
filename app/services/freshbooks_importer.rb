# app/services/freshbooks_importer.rb
# 
# Service to import time entries from FreshBooks CSV export
#
# Expected FreshBooks CSV columns:
# Date, Project, Client, Duration (in hours), Notes
#
# Usage:
#   importer = FreshBooksImporter.new(file_path, admin_user)
#   result = importer.import
#   result.success?  # true/false
#   result.entries_created
#   result.errors

require 'csv'

class FreshBooksImporter
  attr_reader :file_path, :admin_user, :entries_created, :errors

  def initialize(file_path, admin_user)
    @file_path = file_path
    @admin_user = admin_user
    @entries_created = 0
    @errors = []
  end

  def import
    unless admin_user&.admin?
      @errors << "Only admins can import time entries"
      return self
    end

    unless File.exist?(file_path)
      @errors << "File not found: #{file_path}"
      return self
    end

    CSV.foreach(file_path, headers: true) do |row|
      import_row(row)
    end

    self
  end

  def success?
    @errors.empty?
  end

  def summary
    "Imported #{@entries_created} time entries with #{@errors.count} errors"
  end

  private

  def import_row(row)
    # Parse CSV columns (customize as needed based on FreshBooks format)
    date_str = row['Date'] || row['date']
    project_name = row['Project'] || row['project']
    client_name = row['Client'] || row['client']
    hours_str = row['Duration'] || row['Hours'] || row['hours']
    description = row['Notes'] || row['Description'] || row['notes']

    # Validate required fields
    unless date_str && project_name && client_name && hours_str
      @errors << "Missing required fields in row: #{row.to_h}"
      return
    end

    # Parse date
    begin
      date = Date.parse(date_str)
    rescue ArgumentError => e
      @errors << "Invalid date '#{date_str}': #{e.message}"
      return
    end

    # Parse hours
    hours = begin
      Float(hours_str)
    rescue ArgumentError
      @errors << "Invalid hours '#{hours_str}' for #{project_name}"
      return
    end

    # Find or create client
    client = Client.find_or_create_by(name: client_name, user_id: admin_user.id)

    # Find or create project
    project = Project.find_or_create_by(
      name: project_name,
      client_id: client.id,
      user_id: admin_user.id
    )

    # Create time entry
    entry = TimeEntry.new(
      user_id: admin_user.id,
      project_id: project.id,
      date: date,
      hours: hours,
      description: description
    )

    if entry.save
      @entries_created += 1
    else
      @errors << "Failed to save entry for #{project_name} on #{date_str}: #{entry.errors.full_messages.join(', ')}"
    end
  rescue StandardError => e
    @errors << "Unexpected error processing row: #{e.message}"
  end
end

# Usage in controller (example):
#
# class ImportsController < ApplicationController
#   def create
#     unless current_user.admin?
#       redirect_to root_path, alert: "Admin only"
#       return
#     end
#
#     file = params[:file]
#     importer = FreshBooksImporter.new(file.path, current_user)
#     result = importer.import
#
#     if result.success?
#       redirect_to time_entries_path, notice: result.summary
#     else
#       redirect_to new_import_path, alert: result.errors.join(", ")
#     end
#   end
# end
