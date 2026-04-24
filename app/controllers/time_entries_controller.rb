require 'csv'

class TimeEntriesController < ApplicationController
  PER_PAGE = 40
  helper_method :index_filter_params

  before_action :set_time_entry, only: [:show, :edit, :update, :destroy]
  before_action :authorize_time_entry_access, only: [:show, :edit, :update, :destroy]

  def index
    prepare_index_state

    respond_to do |format|
      format.html
      format.csv { send_csv_export }
    end
  end

  def new
    redirect_to time_entries_path(show_log_time: 1)
  end

  def create
    @time_entry = current_user.time_entries.build(time_entry_params)

    if @time_entry.save
      respond_to do |format|
        format.html do
          if return_to_project.present?
            redirect_to project_path(
              return_to_project,
              {
                source: params[:source].presence,
                highlight_time_entry_id: @time_entry.id,
                highlight_time_entry_state: "created"
              }.compact
            )
          else
            redirect_to time_entries_redirect_path(time_entries_url(index_filter_params_from_request), keep_create_panel: false), notice: "Time entry created successfully"
          end
        end
        format.json { render json: time_entry_payload(@time_entry), status: :created }
      end
    else
      respond_to do |format|
        format.html do
          redirect_to time_entries_redirect_path(time_entries_url(index_filter_params_from_request.merge(show_log_time: 1))),
                      alert: @time_entry.errors.full_messages.to_sentence.presence || "Unable to create time entry"
        end
        format.json { render json: { error: @time_entry.errors.full_messages.to_sentence }, status: :unprocessable_entity }
      end
    end
  rescue ArgumentError => error
    @time_entry = current_user.time_entries.build(invalid_time_entry_attributes)
    @time_entry.errors.add(:hours, error.message)

    respond_to do |format|
      format.html do
        redirect_to time_entries_redirect_path(time_entries_url(index_filter_params_from_request.merge(show_log_time: 1))),
                    alert: @time_entry.errors.full_messages.to_sentence
      end
      format.json { render json: { error: @time_entry.errors.full_messages.to_sentence }, status: :unprocessable_entity }
    end
  end

  def show
  end

  def edit
    @projects = Project.for_user(current_user, admin_view_all?).active.includes(:client).order(:name)
  end

  def update
    if @time_entry.update(time_entry_params)
      respond_to do |format|
        format.html { redirect_to time_entries_redirect_path(time_entries_url), notice: "Time entry updated successfully" }
        format.json { render json: time_entry_payload(@time_entry) }
      end
    else
      respond_to do |format|
        format.html do
          @projects = Project.for_user(current_user, admin_view_all?).active.includes(:client).order(:name)
          render :edit, status: :unprocessable_entity
        end
        format.json { render json: { error: @time_entry.errors.full_messages.to_sentence }, status: :unprocessable_entity }
      end
    end
  rescue ArgumentError => error
    @time_entry.assign_attributes(invalid_time_entry_attributes)
    @time_entry.errors.add(:hours, error.message)

    respond_to do |format|
      format.html do
        @projects = Project.for_user(current_user, admin_view_all?).active.includes(:client).order(:name)
        render :edit, status: :unprocessable_entity
      end
      format.json { render json: { error: @time_entry.errors.full_messages.to_sentence }, status: :unprocessable_entity }
    end
  end

  def destroy
    @time_entry.destroy

    respond_to do |format|
      format.html { redirect_to time_entries_redirect_path(time_entries_url), notice: "Time entry deleted successfully" }
      format.json { render json: { time_entry: { id: @time_entry.id } } }
    end
  end

  private

  def set_time_entry
    @time_entry = TimeEntry.find(params[:id])
  end

  def authorize_time_entry_access
    authorize_user_resource(@time_entry)
  end

  def time_entry_params
    permitted = params.require(:time_entry).permit(:project_id, :date, :hours, :description, :billable)
    permitted[:hours] = normalize_hours_input(permitted[:hours])
    permitted[:status] = normalized_status_from(permitted.delete(:billable))
    permitted
  end

  def prepare_index_state
    @filter_start_date = selected_start_date
    @filter_end_date = selected_end_date
    @filter_query = params[:query].to_s.strip
    @date_filter_active = @filter_start_date.present? || @filter_end_date.present?
    @show_log_time_form = params[:show_log_time] == "1"
    @time_entry ||= TimeEntry.new(date: Date.current, status: "unbilled")
    @projects = Project.for_user(current_user, admin_view_all?).active.includes(:client).order(:name)

    base_query = filtered_entries_scope
    @grand_total = base_query.sum(:hours)
    @total_entries = base_query.count
    @total_pages = [(@total_entries.to_f / PER_PAGE).ceil, 1].max
    @page = [[current_page_number, 1].max, @total_pages].min

    entries_query = base_query.ordered.offset((@page - 1) * PER_PAGE).limit(PER_PAGE)
    @time_entries = entries_query.includes(:user, project: :client).to_a
    @page_total = @time_entries.sum(&:hours)
  end

  def send_csv_export
    csv_data = generate_csv(filtered_entries_scope.ordered.includes(project: :client))
    filename = if @date_filter_active
      start_token = @filter_start_date&.strftime("%Y%m%d") || "from_start"
      end_token = @filter_end_date&.strftime("%Y%m%d") || "to_today"
      "time_entries_#{start_token}_#{end_token}.csv"
    elsif @filter_query.present?
      "time_entries_search.csv"
    else
      "time_entries_all.csv"
    end
    send_data csv_data, filename:, type: "text/csv", disposition: "attachment"
  end

  def generate_csv(entries)
    CSV.generate do |csv|
      csv << ["Date", "Project", "Client", "Hours", "Description"]
      entries.each do |entry|
        csv << [
          entry.date.strftime("%Y-%m-%d"),
          entry.project.name,
          entry.project.client.name,
          entry.hours,
          entry.description.to_s
        ]
      end
    end
  end

  def time_entry_payload(entry)
    {
      time_entry: {
        id: entry.id,
        project_id: entry.project_id,
        project_name: entry.project.name,
        client_name: entry.project.client.name,
        date: entry.date.strftime("%Y-%m-%d"),
        hours: view_context.format_hours_as_clock(entry.hours),
        input_hours: view_context.format_hours_as_clock(entry.hours),
        raw_hours: entry.hours.to_s,
        description: entry.description.to_s,
        billable: entry.billable?
      }
    }
  end

  def filtered_entries_scope
    scope = TimeEntry.for_user(current_user, admin_view_all?)
    scope = scope.where("time_entries.date >= ?", @filter_start_date) if @filter_start_date.present?
    scope = scope.where("time_entries.date <= ?", @filter_end_date) if @filter_end_date.present?

    if @filter_query.present?
      pattern = "%#{ActiveRecord::Base.sanitize_sql_like(@filter_query)}%"
      scope = scope.joins(project: :client).where(
        "clients.name LIKE :pattern OR projects.name LIKE :pattern OR time_entries.description LIKE :pattern",
        pattern:
      )
    end

    scope
  end

  def selected_start_date
    parse_date_param(params[:start_date])
  end

  def selected_end_date
    candidate = parse_date_param(params[:end_date])
    return candidate if selected_start_date.blank? || candidate.blank?

    [candidate, selected_start_date].max
  end

  def parse_date_param(value)
    return if value.blank?

    Date.iso8601(value)
  rescue ArgumentError, Date::Error
    nil
  end

  def index_filter_params
    {
      start_date: @filter_start_date.to_s,
      end_date: @filter_end_date.to_s,
      query: @filter_query.presence,
      page: (@page if defined?(@page) && @page > 1)
    }.compact
  end

  def index_filter_params_from_request
    {
      start_date: parse_date_param(params[:start_date])&.to_s,
      end_date: parse_date_param(params[:end_date])&.to_s,
      query: params[:query].presence,
      page: positive_integer(params[:page])
    }.compact
  end

  def normalize_hours_input(value)
    normalized = value.to_s.strip
    raise ActionController::BadRequest, "Hours can't be blank" if normalized.blank?

    if normalized.include?(":")
      parts = normalized.split(":")
      raise ArgumentError, "Use HH:MM for hours" unless parts.length == 2
      raise ArgumentError, "Hours must contain only numbers" unless parts.all? { |part| part.match?(/\A\d+\z/) }

      hours = parts[0].to_i
      minutes = parts[1].to_i
      raise ArgumentError, "Minutes must be less than 60" if minutes >= 60

      return BigDecimal(((hours * 60) + minutes).to_s) / 60
    end

    decimal_hours = BigDecimal(normalized)
    raise ArgumentError, "Hours must be zero or greater" if decimal_hours.negative?

    decimal_hours
  rescue ArgumentError
    raise
  rescue StandardError
    raise ArgumentError, "Use HH:MM or a decimal like 1.25"
  end

  def invalid_time_entry_attributes
    permitted = params.fetch(:time_entry, {}).permit(:project_id, :date, :hours, :description, :billable)
    permitted[:status] = normalized_status_from(permitted.delete(:billable)) if permitted.key?(:billable)
    permitted
  end

  def normalized_status_from(billable_value)
    return "billed" if @time_entry&.billed?
    return "unbilled" if billable_value.nil?

    if ActiveModel::Type::Boolean.new.cast(billable_value)
      @time_entry&.status == "billed" ? "billed" : "unbilled"
    else
      "non-billable"
    end
  end

  def time_entries_redirect_path(default_path, keep_create_panel: params[:show_log_time].present?)
    project = return_to_project
    return default_path unless project

    project_path(project, { source: params[:source].presence, show_log_time: (params[:show_log_time].presence if keep_create_panel) }.compact)
  end

  def return_to_project
    return unless params[:return_to_project_id].present?

    @return_to_project ||= Project.for_user(current_user, admin_view_all?).find_by(id: params[:return_to_project_id])
  end

  def current_page_number
    positive_integer(params[:page]) || 1
  end

  def positive_integer(value)
    parsed = Integer(value, 10)
    parsed.positive? ? parsed : nil
  rescue ArgumentError, TypeError
    nil
  end
end
