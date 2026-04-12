class TimersController < ApplicationController
  before_action :set_timer, except: :create
  rescue_from ActiveRecord::RecordNotFound, with: :handle_project_not_found
  rescue_from ArgumentError, with: :handle_invalid_timer_input

  def create
    if current_user.timer.present?
      redirect_back fallback_location: time_entries_path, alert: "You already have a live timer running"
      return
    end

    @timer = current_user.build_timer(timer_params.merge(started_at: Time.current, state: :running))

    if @timer.save
      redirect_back fallback_location: time_entries_path
    else
      redirect_back fallback_location: time_entries_path, alert: @timer.errors.full_messages.to_sentence.presence || "Unable to start timer"
    end
  end

  def update
    if params[:timer_action] == "log"
      log_timer
    else
      update_attributes = timer_update_params

      if @timer.update(update_attributes)
        respond_to do |format|
          format.html { redirect_back fallback_location: time_entries_path, notice: "Timer updated" }
          format.json { render json: timer_payload(@timer) }
        end
      else
        respond_to do |format|
          format.html { redirect_back fallback_location: time_entries_path, alert: @timer.errors.full_messages.to_sentence }
          format.json { render json: { error: @timer.errors.full_messages.to_sentence }, status: :unprocessable_entity }
        end
      end
    end
  end

  def pause
    @timer.pause!
    redirect_back fallback_location: time_entries_path
  end

  def resume
    @timer.resume!
    redirect_back fallback_location: time_entries_path
  end

  def destroy
    @timer.destroy
    redirect_back fallback_location: time_entries_path, notice: "Timer discarded"
  end

  private

  def set_timer
    @timer = current_user.timer
    return if @timer

    redirect_back fallback_location: time_entries_path, alert: "No active timer found"
  end

  def timer_params
    permitted = params.fetch(:timer, {}).permit(:project_id, :description)
    normalize_project_param(permitted)
  end

  def timer_update_params
    permitted = params.fetch(:timer, {}).permit(:project_id, :description, :elapsed_input)
    attrs = normalize_project_param(permitted.except(:elapsed_input))

    return attrs if permitted[:elapsed_input].blank?

    elapsed_seconds = parse_elapsed_input(permitted[:elapsed_input])
    attrs[:accumulated_seconds] = elapsed_seconds
    attrs[:started_at] = Time.current if @timer.running?
    attrs
  end

  def normalize_project_param(permitted)

    return permitted.except(:project_id) if permitted[:project_id].blank?

    project = available_projects.find_by(id: permitted[:project_id])

    if project.blank?
      raise ActiveRecord::RecordNotFound, "Project not found"
    end

    permitted[:project_id] = project.id
    permitted
  end

  def parse_elapsed_input(value)
    normalized = value.to_s.strip
    raise ArgumentError, "Tracked time can't be blank" if normalized.blank?

    if normalized.include?(":")
      parts = normalized.split(":")
      raise ArgumentError, "Use HH:MM for tracked time" unless parts.length == 2
      raise ArgumentError, "Tracked time must contain only numbers" unless parts.all? { |part| part.match?(/\A\d+\z/) }

      hours = parts[0].to_i
      minutes = parts[1].to_i

      raise ArgumentError, "Minutes must be less than 60" if minutes >= 60

      return (hours * 3600) + (minutes * 60)
    end

    decimal_hours = Float(normalized)
    raise ArgumentError, "Tracked time must be zero or greater" if decimal_hours.negative?

    (decimal_hours * 3600).round
  rescue ArgumentError
    raise
  rescue StandardError
    raise ArgumentError, "Use HH:MM or a decimal like 0.25"
  end

  def available_projects
    current_user.admin? ? Project.all : current_user.projects
  end

  def log_timer
    @timer.assign_attributes(timer_update_params)
    entry = @timer.build_time_entry

    unless entry.valid?
      redirect_back fallback_location: time_entries_path, alert: entry.errors.full_messages.to_sentence
      return
    end

    Timer.transaction do
      entry.save!
      @timer.destroy!
    end

    redirect_to time_entries_path, notice: "Time entry created successfully"
  rescue ActiveRecord::RecordInvalid => error
    redirect_back fallback_location: time_entries_path, alert: error.record.errors.full_messages.to_sentence
  end

  def handle_project_not_found
    respond_to do |format|
      format.html { redirect_back fallback_location: time_entries_path, alert: "Project not found" }
      format.json { render json: { error: "Project not found" }, status: :not_found }
    end
  end

  def handle_invalid_timer_input(error)
    respond_to do |format|
      format.html { redirect_back fallback_location: time_entries_path, alert: error.message }
      format.json { render json: { error: error.message }, status: :unprocessable_entity }
    end
  end

  def timer_payload(timer)
    {
      timer: {
        state: timer.state,
        accumulated_seconds: timer.accumulated_seconds,
        started_at: timer.started_at&.iso8601,
        elapsed_seconds: timer.elapsed_seconds,
        project_id: timer.project_id,
        project_name: timer.project&.name,
        client_name: timer.project&.client&.name,
        description: timer.description
      }
    }
  end
end
