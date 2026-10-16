# CUSTOMIZAÇÃO_SYNAPSEOS
# Importa a planilha padrão da base de conhecimento (.xlsx):
# - aba "conhecimento": uma linha por versão (chave = modelo + versão);
# - aba "fotos_modelos" (opcional): modelo | cor | url.
# Com commit: false só calcula a prévia (novos / atualizados / iguais e avisos).
# A linha da planilha define o veículo inteiro; fotos só são trocadas quando o
# modelo aparece na aba de fotos, e apelidos só quando a coluna existe.
class Synapseos::VehicleSpreadsheetImport
  class InvalidFile < StandardError; end

  VEHICLES_SHEET = 'conhecimento'.freeze
  PHOTOS_SHEET = 'fotos_modelos'.freeze
  IGNORED_HEADERS = %w[id].freeze

  def initialize(account, file)
    @account = account
    @file = file
    @warnings = []
  end

  def call(commit:)
    rows = vehicle_rows
    photos = photo_rows(rows)
    results = ActiveRecord::Base.transaction { rows.map { |row| import_row(row, photos, commit) } }
    { summary: summarize(results), rows: results, warnings: @warnings }
  end

  private

  def vehicles
    Synapseos::Vehicle.where(account_id: @account.id)
  end

  def spreadsheet
    @spreadsheet ||= Roo::Excelx.new(@file.respond_to?(:path) ? @file.path : @file.to_s, file_warning: :ignore)
  rescue StandardError
    raise InvalidFile, 'Arquivo inválido: envie a planilha no formato .xlsx.'
  end

  def sheet_named(name)
    found = spreadsheet.sheets.find { |s| Synapseos::VehicleSchema.header_key(s) == name }
    found && spreadsheet.sheet(found)
  end

  def vehicle_rows
    sheet = sheet_named(VEHICLES_SHEET)
    raise InvalidFile, "A planilha precisa de uma aba \"#{VEHICLES_SHEET}\"." unless sheet

    headers = sheet.row(1).map { |h| Synapseos::VehicleSchema.header_key(h) }
    unknown = headers.compact_blank - Synapseos::VehicleSchema::TYPES.keys - %w[aliases] - IGNORED_HEADERS
    @warnings << { code: 'unknown_columns', columns: unknown } if unknown.any?
    raise InvalidFile, 'A aba "conhecimento" precisa da coluna "modelo".' unless headers.include?('modelo')

    @has_aliases = headers.include?('aliases')
    rows_by_identity(sheet, headers)
  end

  def rows_by_identity(sheet, headers)
    (2..sheet.last_row.to_i).each_with_object({}) do |line, acc|
      row = parse_row(headers, sheet.row(line))
      next if row.nil?
      next @warnings << { code: 'missing_model', line: line } if row['modelo'].blank?

      identity = [row['modelo'].downcase, row['versao'].to_s.downcase]
      @warnings << { code: 'duplicated_row', line: line, modelo: row['modelo'] } if acc.key?(identity)
      acc[identity] = row.merge('_line' => line)
    end.values
  end

  def parse_row(headers, values)
    return nil if values.all?(&:blank?)

    raw = headers.each_with_index.to_h { |key, i| [key, values[i]] }.slice(*Synapseos::VehicleSchema::TYPES.keys, 'aliases')
    raw.to_h { |key, value| [key, Synapseos::VehicleSchema.cast(key, value)] }
  end

  def photo_rows(rows)
    sheet = sheet_named(PHOTOS_SHEET)
    return {} unless sheet

    by_model = photos_by_model(sheet)
    orphan = by_model.keys - rows.map { |r| r['modelo'].downcase }
    @warnings << { code: 'photos_without_model', modelos: orphan.map { |k| @photo_names[k] }.sort } if orphan.any?
    by_model
  end

  def photos_by_model(sheet)
    headers = sheet.row(1).map { |h| Synapseos::VehicleSchema.header_key(h) }
    @photo_names = {}
    (2..sheet.last_row.to_i).each_with_object(Hash.new { |h, k| h[k] = [] }) do |line, acc|
      modelo, photo = parse_photo(headers.zip(sheet.row(line)).to_h)
      next unless photo

      @photo_names[modelo.downcase] ||= modelo
      acc[modelo.downcase] << photo
    end
  end

  def parse_photo(values)
    modelo = Synapseos::VehicleSchema.cast_string(values['modelo'])
    url = Synapseos::VehicleSchema.cast_string(values['url'])
    return [nil, nil] if modelo.blank? || url.blank?

    [modelo, { 'label' => Synapseos::VehicleSchema.cast_string(values['cor'] || values['label']), 'url' => url }]
  end

  def import_row(row, photos, commit)
    vehicle = vehicles.find_by_identity(row['modelo'], row['versao']) || vehicles.new
    status = vehicle.new_record? ? 'created' : 'updated'
    vehicle.assign_attributes(attributes_for(row, photos))
    status = 'unchanged' if status == 'updated' && !vehicle.changed?
    vehicle.save! if commit && status != 'unchanged'
    { line: row['_line'], modelo: row['modelo'], versao: row['versao'], status: status, fotos: vehicle.fotos.size }
  end

  def attributes_for(row, photos)
    attrs = row.slice(*Synapseos::VehicleSchema::CORE_FIELDS)
    attrs['versao'] = attrs['versao'].to_s
    attrs['disponivel'] = true if attrs['disponivel'].nil?
    attrs['specs'] = row.slice(*Synapseos::VehicleSchema::SPEC_FIELDS).compact
    attrs['aliases'] = row['aliases'] || [] if @has_aliases
    model_photos = photos[row['modelo'].downcase]
    attrs['fotos'] = model_photos if model_photos.present?
    attrs
  end

  def summarize(results)
    counts = results.group_by { |r| r[:status] }.transform_values(&:size)
    { total: results.size, created: counts['created'] || 0, updated: counts['updated'] || 0, unchanged: counts['unchanged'] || 0 }
  end
end
