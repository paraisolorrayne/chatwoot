# frozen_string_literal: true

require 'faraday'
require 'faraday/retry'

module Synapseos; end

# Cliente HTTP read-only pro data lake do Fykos (attra-py). Diferente do
# AgenticClient (basic auth pro painel n8n): aqui e service-token
# (header X-Fykos-Token) pro read-API dos paineis da Angela (ADR-001 Opcao A).
#
# Config por ENV:
#   FYKOS_ATTRA_API_URL   - base do web do attra-py (ex.: http://attra-web:8000)
#   FYKOS_DASHBOARD_TOKEN - mesmo token que o attra-py exige (X-Fykos-Token)
#
# A fonte da verdade e o attra-py; este cliente nao cacheia nem persiste.
class Synapseos::FykosAttraClient
  Result = Struct.new(:ok, :status, :data, :message, keyword_init: true) do
    def ok?
      ok == true
    end
  end

  DEFAULT_TIMEOUT = 15

  class << self
    def from_env
      new(base_url: ENV.fetch('FYKOS_ATTRA_API_URL', nil),
          token: ENV.fetch('FYKOS_DASHBOARD_TOKEN', nil))
    end

    def configured?
      ENV['FYKOS_ATTRA_API_URL'].to_s.strip.present?
    end
  end

  def initialize(base_url:, token:, timeout: DEFAULT_TIMEOUT)
    raise ArgumentError, 'FYKOS_ATTRA_API_URL ausente' if base_url.to_s.strip.empty?

    @base_url = base_url.to_s.chomp('/')
    @token = token
    @timeout = timeout
  end

  # section: 'patrimonio' | 'ciclo' | 'resultados' | 'operacional' | 'memoria'
  #          | 'forecast' | 'grafo'
  # params: query string (ex.: operacional => {desde:, ate:})
  def dashboard(section, params: {})
    get("/admin-api/angela/dashboard/#{section}", params)
  end

  private

  def conn
    @conn ||= Faraday.new(url: @base_url) do |f|
      f.request :retry, max: 2, interval: 0.2
      f.options.timeout = @timeout
      f.options.open_timeout = 5
    end
  end

  def get(path, params)
    resp = conn.get(path) do |req|
      req.headers['X-Fykos-Token'] = @token if @token.present?
      req.headers['Accept'] = 'application/json'
      req.params = params if params.present?
    end
    return Result.new(ok: true, status: resp.status, data: JSON.parse(resp.body)) if resp.success?

    Result.new(ok: false, status: resp.status, message: "attra-py respondeu #{resp.status}")
  rescue Faraday::Error, JSON::ParserError => e
    Result.new(ok: false, status: 0, message: e.message)
  end
end
