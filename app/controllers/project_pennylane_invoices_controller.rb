class ProjectPennylaneInvoicesController < ApplicationController
  before_action :set_project
  before_action :authorize_project_access
  before_action :require_pennylane_enabled

  def index
    @invoice_query = params[:invoice_query].to_s.strip
    @linked_pennylane_invoices = @project.pennylane_invoices.recent_first.to_a
    @pennylane_invoice_options = Pennylane::Invoices.new.list_for_selector(query: @invoice_query)
  rescue Pennylane::Error => error
    Rails.logger.warn("Pennylane invoice selector unavailable for project=#{@project.id}: #{error.class}: #{error.message}")
    @linked_pennylane_invoices ||= @project.pennylane_invoices.recent_first.to_a
    @pennylane_invoice_options = []
    @pennylane_invoice_selector_error = error.message
  end

  def create
    remote_id = params[:pennylane_invoice_remote_id].to_s.strip
    redirect_to project_pennylane_invoices_path(@project), alert: "Choose a Pennylane invoice to link" and return if remote_id.blank?

    invoice = PennylaneInvoice.cache_from_remote!(Pennylane::Invoices.new.find(remote_id))
    @project.project_pennylane_invoices.find_or_create_by!(pennylane_invoice: invoice)

    redirect_to project_pennylane_invoices_path(@project), notice: "Pennylane invoice linked"
  rescue Pennylane::Error => error
    Rails.logger.warn("Pennylane invoice link failed for project=#{@project.id} remote_invoice=#{remote_id}: #{error.class}: #{error.message}")
    redirect_to project_pennylane_invoices_path(@project), alert: "Could not link Pennylane invoice: #{error.message}"
  end

  def destroy
    @project.project_pennylane_invoices.find(params[:id]).destroy
    redirect_to project_pennylane_invoices_path(@project), notice: "Pennylane invoice unlinked"
  end

  private

  def set_project
    @project = Project.includes(:client).find(params[:project_id])
  end

  def authorize_project_access
    unless admin? || @project.user_id == current_user.id || @project.client.user_id == current_user.id
      redirect_to root_path, alert: "You don't have permission to access this"
    end
  end

  def require_pennylane_enabled
    return if @project.user.pennylane_enabled?

    redirect_to project_path(@project), alert: "Pennylane is not enabled for this project owner"
  end
end
