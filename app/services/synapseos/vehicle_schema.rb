# CUSTOMIZAÇÃO_SYNAPSEOS
# Formato padrão da base de conhecimento de veículos (planilha "conhecimento").
# Campos de CORE_FIELDS são colunas da tabela; o resto vai em `specs`. Os
# cabeçalhos da planilha são as chaves (com os apelidos de SPREADSHEET_ALIASES).
module Synapseos::VehicleSchema
  # Ordem dentro do grupo = ordem no formulário.
  GROUP_FIELDS = {
    'identificacao' => %w[disponivel modelo versao ano_modelo preco categoria descricao caracteristicas diferenciais cores imagem_url],
    'motor' => %w[motor_tipo motor_cilindrada motor_valvulas motor_cilindros motor_potencia motor_torque motor_alimentacao motor_cambio tracao],
    'desempenho' => %w[velocidade_maxima aceleracao_0_100 consumo_urbano consumo_rodoviario capacidade_tanque],
    'eletrico' => %w[bateria autonomia_eletrica recarga_ac recarga_dc v2l],
    'dimensoes' => %w[peso_kg distancia_solo comprimento largura altura entre_eixos angulo_ataque angulo_saida porta_malas pneus rodas],
    'conforto' => %w[teto_solar ar_condicionado bancos som carregamento_wireless retrovisor_fotocromico acabamento_gt],
    'tecnologia' => %w[conectividade tela_multimidia painel_digital head_up_display modos_conducao camera_facial],
    'seguranca' => %w[airbags sistema_adas garantia]
  }.freeze

  # Tipo de cada campo; o que não está aqui é texto curto ('string').
  FIELD_TYPES = {
    'disponivel' => 'boolean', 'ano_modelo' => 'integer', 'preco' => 'money', 'imagem_url' => 'url',
    'descricao' => 'text', 'caracteristicas' => 'text', 'diferenciais' => 'text', 'sistema_adas' => 'text',
    'bancos' => 'text', 'conectividade' => 'text'
  }.freeze

  FIELDS = GROUP_FIELDS.flat_map do |group, keys|
    keys.map { |key| { key: key, group: group, type: FIELD_TYPES.fetch(key, 'string') } }
  end.freeze

  CORE_FIELDS = %w[modelo versao ano_modelo preco disponivel categoria descricao imagem_url].freeze
  SPEC_FIELDS = (FIELDS.pluck(:key) - CORE_FIELDS).freeze
  TYPES = FIELDS.to_h { |f| [f[:key], f[:type]] }.freeze

  # Cabeçalho da planilha que difere da chave interna.
  SPREADSHEET_ALIASES = {
    'disponivel_portfolio' => 'disponivel',
    'descricao_principal' => 'descricao',
    'link_imagem' => 'imagem_url',
    'apelidos' => 'aliases'
  }.freeze

  INVISIBLE_CHARS = /[​-‍﻿ ]/

  module_function

  def definition
    { groups: GROUP_FIELDS.keys, fields: FIELDS, core_fields: CORE_FIELDS }
  end

  def header_key(header)
    key = I18n.transliterate(header.to_s).downcase.strip.gsub(/[^a-z0-9]+/, '_').gsub(/\A_+|_+\z/, '')
    SPREADSHEET_ALIASES.fetch(key, key)
  end

  def cast(key, value)
    return cast_aliases(value) if key == 'aliases'

    case TYPES[key]
    when 'money' then cast_money(value)
    when 'integer' then cast_integer(value)
    when 'boolean' then cast_boolean(value)
    else cast_string(value)
    end
  end

  def cast_string(value)
    return nil if value.nil?

    value = value.to_i if value.is_a?(Float) && value == value.floor
    value.to_s.gsub(INVISIBLE_CHARS, ' ').strip.presence
  end

  # "R$ 429.000,00", "R$ 169.000", 199000.0 → BigDecimal
  def cast_money(value)
    return value.to_d if value.is_a?(Numeric)

    raw = value.to_s.gsub(/[^\d.,]/, '')
    return nil if raw.empty?

    raw = raw.delete('.').tr(',', '.') if raw.include?(',')
    raw = raw.delete('.') if raw.match?(/\A\d{1,3}(\.\d{3})+\z/)
    BigDecimal(raw)
  rescue ArgumentError
    nil
  end

  def cast_integer(value)
    return value.to_i if value.is_a?(Numeric)

    raw = value.to_s[/\d+([.,]\d+)?/]
    raw && raw.tr(',', '.').to_f.to_i
  end

  def cast_boolean(value)
    return value if [true, false].include?(value)

    text = I18n.transliterate(value.to_s).downcase.strip
    return true if text.empty?

    %w[nao n no false 0 indisponivel].exclude?(text)
  end

  def cast_aliases(value)
    list = value.is_a?(Array) ? value : value.to_s.split(/[,;\n]/)
    list.filter_map { |a| cast_string(a) }.uniq
  end
end
