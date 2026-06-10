# frozen_string_literal: true

# Proxy read-only do painel da Angela (Tier 1) -> read-API do attra-py (data
# lake) via service-token. NAO le tabelas Rails locais (diferente da Elisa): a
# fonte da verdade e o attra-py (ADR-001 Opcao A).
#
# Single-tenant (Attra) nesta fase: o attra-py escopa pra ATTRA_TENANT_ID
# (ADR-011); o mapa account_id -> tenant entra quando o 2o tenant chegar.
class Api::V1::Accounts::Synapseos::Angela::DashboardController < Api::V1::Accounts::BaseController
  before_action :check_authorization
  before_action :ensure_configured

  # --- Estoque (all-time; ignora periodo) ---
  def patrimonio
    proxy('patrimonio')
  end

  def ciclo
    proxy('ciclo')
  end

  def resultados
    proxy('resultados')
  end

  def memoria
    proxy('memoria')
  end

  def grafo
    proxy('grafo')
  end

  def forecast
    proxy('forecast', params: forecast_params)
  end

  # --- Fluxo (reage ao periodo desde/ate) ---
  def operacional
    proxy('operacional', params: operacional_params)
  end

  private

  def proxy(section, params: {})
    res = client.dashboard(section, params: params)
    if res.ok?
      render json: res.data
    else
      render json: { error: 'fonte indisponivel', detail: res.message }, status: :bad_gateway
    end
  end

  def client
    @client ||= ::Synapseos::FykosAttraClient.from_env
  end

  def ensure_configured
    return if ::Synapseos::FykosAttraClient.configured?

    render json: { error: 'painel Angela nao configurado (FYKOS_ATTRA_API_URL)' },
           status: :service_unavailable
  end

  def forecast_params
    h = params[:horizonte_meses].to_i
    h.positive? ? { horizonte_meses: h } : {}
  end

  def operacional_params
    params.permit(:desde, :ate).to_h.compact_blank
  end

  def check_authorization
    authorize(User, :index?)
  end
end
