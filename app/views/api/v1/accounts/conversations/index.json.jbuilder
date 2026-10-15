json.data do
  json.meta do
    json.mine_count @conversations_count[:mine_count]
    json.assigned_count @conversations_count[:assigned_count]
    json.unassigned_count @conversations_count[:unassigned_count]
    json.all_count @conversations_count[:all_count]
    # CUSTOMIZAÇÃO_SYNAPSEOS — contagem da aba "Precisa de você"
    json.needs_human_count @conversations_count[:needs_human_count]
  end
  json.payload do
    json.array! @conversations do |conversation|
      json.partial! 'api/v1/conversations/partials/conversation', formats: [:json], conversation: conversation
    end
  end
end
