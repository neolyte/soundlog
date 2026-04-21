class ClientsController < ApplicationController
  helper_method :clients_index_params

  before_action :set_client, only: [:show, :edit, :update, :destroy]
  before_action :authorize_client_access, only: [:show, :edit, :update, :destroy]

  def index
    @filter_query = params[:query].to_s.strip
    @sort_option = sort_option_param

    @clients = filtered_clients
    @clients_count = @clients.count
    @projects_count = @clients.sum(&:active_projects_count)
    @logged_total = @clients.sum(&:total_hours_logged)
  end

  def new
    @client = Client.new
  end

  def create
    @client = current_user.clients.build(client_params)

    if @client.save
      redirect_to @client, notice: "Client created successfully"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @projects = @client.projects.active.includes(:user, :time_entries).ordered_by_recent_activity.to_a
    @projects_count = @projects.count
    @logged_total = @projects.sum(&:total_hours_logged)
    @budget_total = @projects.filter_map(&:total_hours).sum
    @remaining_total = @projects.filter_map(&:remaining_hours).sum
  end

  def edit
  end

  def update
    if @client.update(client_params)
      redirect_to @client, notice: "Client updated successfully"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @client.destroy
    redirect_to clients_url, notice: "Client deleted successfully"
  end

  private

  def set_client
    @client = Client.find(params[:id])
  end

  def authorize_client_access
    authorize_user_resource(@client)
  end

  def client_params
    params.require(:client).permit(:name)
  end

  def base_clients
    Client.for_user(current_user).includes(:user, projects: :time_entries).to_a
  end

  def filtered_clients
    clients = base_clients

    if @filter_query.present?
      needle = @filter_query.downcase
      clients = clients.select do |client|
        [
          client.name,
          client.user.full_name
        ].compact.any? { |value| value.downcase.include?(needle) }
      end
    end

    case @sort_option
    when "hours_logged"
      clients.sort_by { |client| [-client.total_hours_logged.to_f, client.name.downcase] }
    when "projects"
      clients.sort_by { |client| [-client.active_projects_count, client.name.downcase] }
    else
      clients.sort_by do |client|
        latest_date, latest_created_at = client.latest_activity_sort_key
        [-(latest_date&.jd || 0), -(latest_created_at&.to_i || 0), client.name.downcase]
      end
    end
  end

  def sort_option_param
    return "name" if params[:sort] == "name"
    return "hours_logged" if params[:sort] == "hours_logged"
    return "projects" if params[:sort] == "projects"

    "recent"
  end

  def clients_index_params(overrides = {})
    {
      query: @filter_query.presence,
      sort: (@sort_option unless @sort_option == "recent")
    }.merge(overrides).compact
  end
end
