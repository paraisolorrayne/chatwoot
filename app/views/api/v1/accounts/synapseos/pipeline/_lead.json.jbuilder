conversation = lead.conversation
json.id lead.id
json.pipeline_stage_id lead.pipeline_stage_id
json.status lead.status
json.source lead.source
json.conversation_id lead.conversation_id
# rota do Chatwoot usa display_id; conversation_id é o id interno. Expor o
# display pro board abrir o chat certo (PipelinePage usa conversation_display_id).
json.conversation_display_id conversation&.display_id
json.created_at lead.created_at
json.updated_at lead.updated_at

# CUSTOMIZAÇÃO_SYNAPSEOS: campos de negócio (ADR-003) com fallback pro metadata
# gravado pelo n8n antes das colunas existirem.
metadata = lead.metadata || {}
json.estado lead.estado
json.modelo_interesse lead.modelo_interesse.presence || metadata['modelo_interesse']
json.horizonte_compra lead.horizonte_compra.presence || metadata['horizonte_compra']
json.tem_troca lead.tem_troca
json.forma_pagamento lead.forma_pagamento
json.urgencia lead.urgencia
json.motivo lead.motivo.presence || metadata['loss_reason']
json.next_action_at lead.next_action_at

contact = lead.contact || conversation&.contact
json.contact do
  json.id contact&.id
  json.name contact&.name || 'Sem contato'
  json.email contact&.email
  json.phone_number contact&.phone_number
  json.avatar_url contact&.avatar_url
end

# Quem atende: consultor (lead ou conversa) tem prioridade; senão o bot da inbox.
assignee = lead.assignee || conversation&.assignee
bot_inbox = conversation&.inbox&.agent_bot_inbox
bot = conversation&.assignee_agent_bot || (bot_inbox&.agent_bot if bot_inbox&.active?)
if assignee
  json.handler do
    json.kind 'user'
    json.id assignee.id
    json.name assignee.available_name
    json.avatar_url assignee.avatar_url
  end
elsif bot
  json.handler do
    json.kind 'bot'
    json.id bot.id
    json.name bot.name
    json.squadron_role bot.squadron_role
  end
else
  json.handler nil
end

last_message = @last_messages[lead.conversation_id]
if last_message&.content.present?
  json.last_message do
    json.content last_message.content.truncate(140)
    json.message_type last_message.message_type
    json.created_at last_message.created_at
  end
else
  json.last_message nil
end

last_deal = lead.deals.max_by(&:created_at)
if last_deal.present?
  json.deal do
    json.id last_deal.id
    json.status last_deal.status
    json.amount last_deal.amount.to_f
    json.currency last_deal.currency
    json.closed_at last_deal.closed_at
  end
else
  json.deal nil
end
