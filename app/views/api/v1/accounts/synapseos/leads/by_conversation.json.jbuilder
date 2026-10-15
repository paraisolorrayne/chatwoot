json.partial! 'api/v1/accounts/synapseos/leads/lead', lead: @lead

# CUSTOMIZAÇÃO_SYNAPSEOS: card do lead no painel da conversa (etapa com slug + último handoff).
json.pipeline_stage @lead.pipeline_stage&.slice(:id, :slug, :name, :color, :stage_type)

if @handoff_event
  meta = @handoff_event.metadata
  json.handoff do
    json.event_type @handoff_event.event_type
    json.created_at @handoff_event.created_at
    json.summary meta['observacoes'].presence || meta['user_summary']
    json.modelo_interesse meta['modelo_interesse']
    json.motivo meta['motivo'].presence || meta['tipo']
  end
else
  json.handoff nil
end
