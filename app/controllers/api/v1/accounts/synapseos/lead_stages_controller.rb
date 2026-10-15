# CUSTOMIZAÇÃO_SYNAPSEOS — estágio do lead de cada conversa da lista, em lote
# (chip do card e filtro local da aba "Precisa de você").
#
#   GET /api/v1/accounts/:account_id/synapseos/leads/stages?display_ids[]=12&display_ids[]=13
#   => { "12": { "id": 3, "slug": "...", "name": "...", "stage_type": "working", "needs_human": true }, "13": null }
#
# A chave é o display_id (o id que o frontend usa); synapseos_leads.conversation_id
# guarda o id INTERNO, daí o join com conversations. Conversa sem lead ou sem
# estágio volta null para o cliente não pedir de novo.
class Api::V1::Accounts::Synapseos::LeadStagesController < Api::V1::Accounts::BaseController
  before_action :check_authorization

  COLUMNS = %w[conversations.display_id synapseos_pipeline_stages.id synapseos_pipeline_stages.slug
               synapseos_pipeline_stages.name synapseos_pipeline_stages.stage_type].freeze

  def index
    display_ids = Array(params[:display_ids]).map(&:to_i)
    needs_human_ids = ::Synapseos::NeedsHuman.stage_ids(Current.account)

    stages = ::Synapseos::Lead.where(account_id: Current.account.id)
                              .joins(:conversation, :pipeline_stage)
                              .where(conversations: { display_id: display_ids })
                              .pluck(*COLUMNS)
                              .to_h do |display_id, id, slug, name, stage_type|
      [display_id, { id: id, slug: slug, name: name, stage_type: stage_type, needs_human: needs_human_ids.include?(id) }]
    end

    render json: display_ids.index_with(nil).merge(stages)
  end

  private

  def check_authorization
    authorize(User, :index?)
  end
end
