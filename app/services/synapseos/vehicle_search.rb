# CUSTOMIZAÇÃO_SYNAPSEOS
# Busca da base de conhecimento para o agente de IA ("haval h6 híbrido",
# "picape diesel 4x4"). O catálogo de uma conta é pequeno, então o ranking é
# feito em Ruby: termo no nome/apelido pesa mais que termo no resto da ficha.
class Synapseos::VehicleSearch
  STOPWORDS = %w[de da do das dos um uma o a os as e com para por que qual quero tem tenho sobre].freeze

  def initialize(account, query, limit: 5)
    @account = account
    @query = query
    @limit = limit
  end

  def call
    terms = normalize(@query).split - STOPWORDS
    return [] if terms.empty?

    scored = Synapseos::Vehicle.where(account_id: @account.id).map { |v| [score(v, terms), v] }
    scored.select { |s, _| s.positive? }
          .sort_by { |s, v| [-s, v.disponivel ? 0 : 1, v.modelo] }
          .first(@limit).map(&:last)
  end

  private

  def score(vehicle, terms)
    names = [vehicle.modelo, *vehicle.aliases].map { |n| normalize(n) }
    return 100 if names.include?(terms.join(' '))

    name = normalize("#{vehicle.modelo} #{vehicle.versao} #{vehicle.aliases.join(' ')}")
    text = normalize([vehicle.categoria, vehicle.descricao, *vehicle.specs.values].join(' '))
    terms.sum do |term|
      next 10 if name.include?(term)

      text.include?(term) ? 1 : 0
    end
  end

  def normalize(value)
    I18n.transliterate(value.to_s).downcase.gsub(/[^a-z0-9]+/, ' ').strip
  end
end
