# CUSTOMIZAÇÃO_SYNAPSEOS
# Lê a Inteligência (data lake das conversas) do painel agentic, servidor a
# servidor, com o service token. O painel só responde para a conta que ele
# atende (hoje a Audi), então a página só existe para contas listadas em
# SYNAPSEOS_INTELLIGENCE_ACCOUNT_IDS. Respostas ficam 5 min em cache.
class Synapseos::PanelAnalytics
  SECTIONS = %w[overview forecast voz-cliente demanda pipeline-receita].freeze
  CACHE_TTL = 5.minutes

  class Unavailable < StandardError; end

  def self.enabled_for?(account)
    token.present? && ENV.fetch('SYNAPSEOS_INTELLIGENCE_ACCOUNT_IDS', '').split(',').map(&:strip).include?(account.id.to_s)
  end

  def self.token
    ENV.fetch('SYNAPSEOS_PANEL_SERVICE_TOKEN', '')
  end

  def initialize(account)
    @account = account
  end

  def fetch(section)
    raise Unavailable, 'Inteligência não habilitada para esta conta' unless self.class.enabled_for?(@account)
    raise ArgumentError, "Seção desconhecida: #{section}" unless SECTIONS.include?(section)

    Rails.cache.fetch(['synapseos_panel_analytics', @account.id, section], expires_in: CACHE_TTL) { request(section) }
  end

  private

  def request(section)
    uri = URI("#{ENV.fetch('SYNAPSEOS_PANEL_INTERNAL_URL', 'https://painel.dexidigital.com.br')}/api/analytics/#{section}")
    uri.query = { account_id: @account.id }.to_query
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https', open_timeout: 5, read_timeout: 20) do |http|
      http.get(uri.request_uri, 'X-Panel-Service-Token' => self.class.token, 'Accept' => 'application/json')
    end
    raise Unavailable, "Painel respondeu #{response.code}" unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body)
  rescue Net::OpenTimeout, Net::ReadTimeout, SocketError, Errno::ECONNREFUSED, JSON::ParserError => e
    raise Unavailable, "Painel indisponível: #{e.class.name}"
  end
end
