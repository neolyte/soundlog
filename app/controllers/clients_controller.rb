class ClientsController < ApplicationController
  before_action :set_client, only: [:show, :edit, :update, :destroy]
  before_action :authorize_client_access, only: [:show, :edit, :update, :destroy]

  def index
    @clients = current_user.admin? ? Client.all : current_user.clients
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
end
