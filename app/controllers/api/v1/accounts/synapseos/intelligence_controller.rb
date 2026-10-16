# CUSTOMIZAÇÃO_SYNAPSEOS
# Inteligência nativa: repassa uma seção do data lake do painel agentic
# (Synapseos::PanelAnalytics). Mesmo público do Dashboard executivo.
class Api::V1::Accounts::Synapseos::IntelligenceController < Api::V1::Accounts::BaseController
  before_action :check_authorization

  def show
    render json: ::Synapseos::PanelAnalytics.new(Current.account).fetch(params[:section])
  rescue ArgumentError => e
    render json: { error: e.message }, status: :not_found
  rescue ::Synapseos::PanelAnalytics::Unavailable => e
    render json: { error: e.message }, status: :service_unavailable
  end

  private

  def check_authorization
    render_unauthorized('Acesso restrito') unless Current.account_user&.permissions&.include?('synapseos_intelligence')
  end
end
