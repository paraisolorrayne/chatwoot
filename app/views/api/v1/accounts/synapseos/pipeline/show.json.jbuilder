json.stages @stages do |stage|
  json.partial! 'api/v1/accounts/synapseos/pipeline_stages/pipeline_stage', pipeline_stage: stage
  # CUSTOMIZAÇÃO_SYNAPSEOS: o board usa o slug pra destacar/recolher colunas (futuro, aguardando_atendimento_humano).
  json.slug stage.try(:slug)
end

# CUSTOMIZAÇÃO_SYNAPSEOS: card do board em partial (campos de negócio, quem atende, última mensagem).
json.leads @leads, partial: 'api/v1/accounts/synapseos/pipeline/lead', as: :lead
