# == Schema Information
#
# Table name: synapseos_vehicles
#
#  id         :bigint           not null, primary key
#  aliases    :string           default([]), not null, is an Array
#  ano_modelo :integer
#  categoria  :string
#  descricao  :text
#  disponivel :boolean          default(TRUE), not null
#  fotos      :jsonb            not null
#  imagem_url :string
#  modelo     :string           not null
#  preco      :decimal(12, 2)
#  specs      :jsonb            not null
#  versao     :string           default(""), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  account_id :bigint           not null
#
# Indexes
#
#  idx_synapseos_vehicles_on_account_modelo_versao  (account_id, lower((modelo)::text), lower((versao)::text)) UNIQUE
#  index_synapseos_vehicles_on_account_id           (account_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#
# CUSTOMIZAÇÃO_SYNAPSEOS
# Base de conhecimento de veículos da conta (formato padrão em
# Synapseos::VehicleSchema). Fonte da verdade para o agente de IA consultar.
class Synapseos::Vehicle < ApplicationRecord
  self.table_name = 'synapseos_vehicles'

  belongs_to :account

  before_validation :normalize_values

  validates :modelo, presence: true
  validates :modelo, uniqueness: { scope: [:account_id, :versao], case_sensitive: false }

  scope :ordered, -> { order(Arel.sql('lower(modelo), lower(versao)')) }

  def self.find_by_identity(modelo, versao)
    find_by('lower(modelo) = ? AND lower(versao) = ?', modelo.to_s.downcase, versao.to_s.downcase)
  end

  # Percentual dos campos do formato padrão preenchidos (orienta o cliente a
  # completar a base: o agente só responde o que estiver aqui).
  def completude
    total = Synapseos::VehicleSchema::FIELDS.size
    filled = Synapseos::VehicleSchema::CORE_FIELDS.count { |k| self[k].present? || self[k] == false } + specs.size
    ((filled * 100.0) / total).round
  end

  def as_api_json
    {
      id: id, modelo: modelo, versao: versao, ano_modelo: ano_modelo, preco: preco&.to_f,
      disponivel: disponivel, categoria: categoria, descricao: descricao, imagem_url: imagem_url,
      aliases: aliases, specs: specs, fotos: fotos, completude: completude, updated_at: updated_at
    }
  end

  private

  def normalize_values
    self.versao = versao.to_s.strip
    self.aliases = Synapseos::VehicleSchema.cast_aliases(aliases)
    self.specs = (specs || {}).to_h.slice(*Synapseos::VehicleSchema::SPEC_FIELDS)
                              .transform_values { |v| Synapseos::VehicleSchema.cast_string(v) }.compact
    self.fotos = Array(fotos).filter_map do |foto|
      foto = foto.to_h.stringify_keys
      url = Synapseos::VehicleSchema.cast_string(foto['url'])
      { 'label' => Synapseos::VehicleSchema.cast_string(foto['label']), 'url' => url } if url
    end
  end
end
