# CUSTOMIZAÇÃO_SYNAPSEOS — o que é "precisa de humano" na lista de conversas
# (aba "Precisa de você" e chip de estágio do card).
#
# Lead no estágio 'aguardando_atendimento_humano' ("Aguardando equipe"): a IA fez
# o handoff e o lead espera um consultor. Contas com outro template de pipeline
# não têm esse slug; nelas valem os estágios stage_type 'working' (conduzidos
# por humanos), para a aba não ficar sempre vazia.
module Synapseos::NeedsHuman
  STAGE_SLUG = 'aguardando_atendimento_humano'.freeze

  module_function

  def stage_ids(account)
    stages = ::Synapseos::PipelineStage.where(account_id: account.id)
    stages.where(slug: STAGE_SLUG).ids.presence || stages.where(stage_type: 'working').ids
  end

  # Subquery com ids INTERNOS: synapseos_leads.conversation_id aponta para
  # conversations.id, não para o display_id.
  def conversation_ids(account)
    ::Synapseos::Lead.where(account_id: account.id, pipeline_stage_id: stage_ids(account)).select(:conversation_id)
  end
end
