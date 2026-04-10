require 'csv'

class TimeEntriesController < ApplicationController
  before_action :set_time_entry, only: [:show, :edit, :update, :destroy]
  before_action :authorize_time_entry_access, only: [:show, :edit, :update, :destroy]

  def index
    @current_month = params[:month].present? ? Date.parse(params[:month]) : Date.current
    
    entries_query = current_user.admin? ? TimeEntry.all : current_user.time_entries
    @time_entries = entries_query.for_month(@current_month).ordered
    
    @monthly_total = @time_entries.sum(:hours)
    @entries_by_date = @time_entries.group_by(&:date).sort.reverse

    respond_to do |format|
      format.html
      format.csv { send_csv_export }
    end
  end

  def new
    @time_entry = TimeEntry.new(date: Date.current)
    @projects = current_user.admin? ? Project.all : current_user.projects
  end

  def create
    @time_entry = current_user.time_entries.build(time_entry_params)

    if @time_entry.save
      redirect_to time_entries_url, notice: "Time entry created successfully"
    else
      @projects = current_user.admin? ? Project.all : current_user.projects
      render :new, status: :unprocessable_entity
    end
  end

  def show
  end

  def edit
    @projects = current_user.admin? ? Project.all : current_user.projects
  end

  def update
    if @time_entry.update(time_entry_params)
      redirect_to time_entries_url, notice: "Time entry updated successfully"
    else
      @projects = current_user.admin? ? Project.all : current_user.projects
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @time_entry.destroy
    redirect_to time_entries_url, notice: "Time entry deleted successfully"
  end

  private

  def set_time_entry
    @time_entry = TimeEntry.find(params[:id])
  end

  def authorize_time_entry_access
    authorize_user_resource(@time_entry)
  end

  def time_entry_params
    params.require(:time_entry).permit(:project_id, :date, :hours, :description)
  end

  def send_csv_export
    csv_data = generate_csv(@time_entries)
    filename = "time_entries_#{@current_month.strftime('%Y%m%d')}.csv"
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
end
