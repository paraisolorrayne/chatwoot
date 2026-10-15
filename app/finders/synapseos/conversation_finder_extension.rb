# CUSTOMIZAÇÃO_SYNAPSEOS — aba "Precisa de você" da lista de conversas.
# assignee_type=needs_human lista só as conversas cujo lead precisa de um humano
# (Synapseos::NeedsHuman), da espera mais antiga para a mais recente. Todas as
# respostas trazem needs_human_count junto das contagens das outras abas.
module Synapseos::ConversationFinderExtension
  NEEDS_HUMAN = 'needs_human'.freeze
  # waiting_since = 1ª mensagem do cliente ainda sem resposta. Quando a última
  # palavra foi da IA (a mensagem de handoff), o cliente espera desde a última atividade.
  WAITING_ORDER = Arel.sql('COALESCE(conversations.waiting_since, conversations.last_activity_at) ASC')

  def perform
    super.tap { |result| result[:count][:needs_human_count] = @needs_human_count }
  end

  def perform_meta_only
    super.tap { |result| result[:count][:needs_human_count] = @needs_human_count }
  end

  private

  def set_count_for_all_conversations
    @needs_human_count = needs_human_conversations.count
    super
  end

  def filter_by_assignee_type
    return super unless @assignee_type == NEEDS_HUMAN

    @conversations = needs_human_conversations.order(WAITING_ORDER)
  end

  def needs_human_conversations
    @needs_human_conversation_ids ||= ::Synapseos::NeedsHuman.conversation_ids(current_account)
    @conversations.where(id: @needs_human_conversation_ids)
  end
end
