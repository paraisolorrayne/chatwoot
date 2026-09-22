# CUSTOMIZAÇÃO_SYNAPSEOS: contatos internos (suporte SynapseOS, operadores)
# nunca entram no fluxo de LLM. Quando um deles escreve numa inbox com
# AgentBot — por exemplo respondendo a um pedido da central de suporte — o
# bot ficaria "conversando" com a própria equipe e confundiria o histórico.
#
# A lista é global (vale para todas as contas do Chatwoot): o número de
# suporte (`SYNAPSEOS_SUPPORT_PHONE`) mais `SYNAPSEOS_INTERNAL_PHONES`
# (separados por vírgula, qualquer formatação). Conversas abertas pela
# central de suporte também contam, mesmo que o número mude.
module Synapseos::InternalContacts
  def self.phones
    raw = [ENV.fetch('SYNAPSEOS_INTERNAL_PHONES', ''), Synapseos::SupportRequestService.phone_number]
    raw.join(',').split(',').map { |value| digits(value) }.reject(&:blank?).to_set
  end

  def self.internal?(conversation)
    return false if conversation.blank?
    return true if conversation.additional_attributes&.dig('synapseos_support')

    candidates = [conversation.contact&.phone_number, conversation.contact_inbox&.source_id]
    candidates.any? { |value| phones.include?(digits(value)) }
  end

  def self.digits(value)
    value.to_s.gsub(/\D/, '')
  end
end
