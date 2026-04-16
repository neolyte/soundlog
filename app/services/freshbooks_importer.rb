require "csv"

class FreshbooksImporter
  DEFAULT_BATCH_SIZE = 500
  DEFAULT_PROGRESS_EVERY = 250
  TIME_ENTRY_COLUMNS = %i[
    user_id
    project_id
    date
    hours
    description
    service_name
    status
    created_at
    updated_at
  ].freeze

  attr_reader :file_path, :user, :entries_created, :errors, :processed_rows, :total_rows, :skipped_rows

  def initialize(file_path, user, batch_size: DEFAULT_BATCH_SIZE, progress_every: nil, progress_io: nil)
    @file_path = file_path
    @user = user
    @batch_size = batch_size
    @progress_every = progress_every
    @progress_io = progress_io
    @entries_created = 0
    @errors = []
    @processed_rows = 0
    @total_rows = 0
    @skipped_rows = 0
    @last_reported_row = nil
    @pending_time_entries = []
    @clients_by_name = {}
    @projects_by_key = {}
  end

  def import
    unless user.present?
      @errors << "User is required"
      return self
    end

    unless File.exist?(file_path)
      @errors << "File not found: #{file_path}"
      return self
    end

    preload_existing_records
    @total_rows = progress_enabled? ? count_rows : 0

    CSV.foreach(file_path, headers: true).with_index(1) do |row, row_number|
      import_row(row)
      @processed_rows = row_number
      flush_time_entries if @pending_time_entries.size >= @batch_size
      report_progress if should_report_progress?
    end

    flush_time_entries
    report_progress(force: true)

    self
  end

  def success?
    @errors.empty?
  end

  def summary
    summary = +"Imported #{@entries_created} time entries for #{user.full_name}"
    summary << ", skipped #{@skipped_rows} zero-duration rows" if @skipped_rows.positive?
    summary << ", with #{@errors.count} errors"
    summary
  end

  private

  def preload_existing_records
    user.clients.find_each do |client|
      @clients_by_name[client.name] = client
    end

    user.projects.includes(:client).find_each do |project|
      @projects_by_key[[project.client_id, project.name]] ||= project
    end
  end

  def import_row(row)
    date_str = text_value(row, "Date")
    project_name = text_value(row, "Project")
    client_name = text_value(row, "Client")
    hours_str = text_value(row, "Hours")
    seconds_str = text_value(row, "Seconds")
    description = text_value(row, "Note")
    service_name = text_value(row, "Service")
    status = text_value(row, "Status")

    unless date_str && project_name && client_name && hours_str
      @errors << "Missing required fields in row: #{row.to_h}"
      return
    end

    date = Date.parse(date_str)
    hours = normalized_hours(hours_str, seconds_str)

    unless hours
      @skipped_rows += 1
      return
    end

    client = find_or_create_client(client_name)
    project = find_or_create_project(project_name, client.id)

    entry = TimeEntry.new(
      user_id: user.id,
      project_id: project.id,
      date: date,
      hours: hours,
      description: description,
      service_name: service_name,
      status: status
    )

    if entry.valid?
      timestamp = Time.current
      @pending_time_entries << entry.attributes.symbolize_keys.slice(*TIME_ENTRY_COLUMNS).merge(
        created_at: timestamp,
        updated_at: timestamp
      )
    else
      @errors << "Failed to save entry for #{project_name} on #{date_str}: #{entry.errors.full_messages.join(', ')}"
    end
  rescue ArgumentError => e
    @errors << "Invalid row data #{row.to_h}: #{e.message}"
  rescue ActiveRecord::RecordInvalid => e
    @errors << "Failed to create records for row #{row.to_h}: #{e.record.errors.full_messages.join(', ')}"
  rescue StandardError => e
    @errors << "Unexpected error processing row #{row.to_h}: #{e.message}"
  end

  def text_value(row, column_name)
    value = row[column_name]
    return if value.nil?

    normalized_value = value.to_s.strip
    normalized_value.presence
  end

  def normalized_hours(hours_str, seconds_str)
    seconds = integer_value(seconds_str)
    if !seconds.nil?
      return if seconds.zero?

      rounded_hours = seconds_to_hours(seconds)
      return BigDecimal("0.01") if rounded_hours.zero?

      return rounded_hours
    end

    hours = BigDecimal(hours_str)
    return if hours.zero?

    hours.round(2)
  end

  def integer_value(value)
    return if value.blank?

    Integer(value, 10)
  rescue ArgumentError
    nil
  end

  def seconds_to_hours(seconds)
    (BigDecimal(seconds.to_s) / 3600).round(2)
  end

  def find_or_create_client(client_name)
    @clients_by_name[client_name] ||= Client.find_or_create_by!(name: client_name, user_id: user.id)
  end

  def find_or_create_project(project_name, client_id)
    key = [client_id, project_name]
    @projects_by_key[key] ||= Project.find_or_create_by!(
      name: project_name,
      client_id: client_id,
      user_id: user.id
    )
  end

  def flush_time_entries
    return if @pending_time_entries.empty?

    batch = @pending_time_entries
    @pending_time_entries = []

    TimeEntry.insert_all!(batch)
    @entries_created += batch.size
  rescue StandardError => e
    @errors << "Bulk insert failed after #{@processed_rows} rows: #{e.message}"
    save_time_entries_individually(batch)
  end

  def save_time_entries_individually(batch)
    batch.each do |attributes|
      entry = TimeEntry.new(attributes.except(:created_at, :updated_at))

      if entry.save
        @entries_created += 1
      else
        @errors << "Failed to save entry for project ##{entry.project_id} on #{entry.date}: #{entry.errors.full_messages.join(', ')}"
      end
    end
  end

  def count_rows
    row_count = 0

    CSV.foreach(file_path, headers: true) { row_count += 1 }

    row_count
  end

  def should_report_progress?
    progress_enabled? && (@processed_rows % @progress_every).zero?
  end

  def report_progress(force: false)
    return unless @progress_io.present?
    return if !force && !should_report_progress?
    return if force && @last_reported_row == @processed_rows

    message = +"Processed #{@processed_rows}"
    message << "/#{@total_rows}" if @total_rows.positive?
    message << " (#{progress_percent}%)" if @total_rows.positive?
    message << " rows"
    message << " | imported #{@entries_created}"
    message << " | errors #{@errors.count}"

    @progress_io.puts(message)
    @last_reported_row = @processed_rows
  end

  def progress_percent
    ((@processed_rows.to_f / @total_rows) * 100).round(1)
  end

  def progress_enabled?
    @progress_io.present? && @progress_every.present?
  end
end
