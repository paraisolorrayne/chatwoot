require 'rails_helper'

RSpec.describe 'Synapseos lead stages API', type: :request do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:stage) do
    create(:synapseos_pipeline_stage, account: account, slug: 'aguardando_atendimento_humano',
                                      name: 'Aguardando equipe', stage_type: 'working')
  end
  let(:with_lead) { create(:conversation, account: account) }
  let(:without_lead) { create(:conversation, account: account) }
  let(:url) { "/api/v1/accounts/#{account.id}/synapseos/leads/stages" }

  before { create(:synapseos_lead, conversation: with_lead, pipeline_stage: stage) }

  it 'returns unauthorized when unauthenticated' do
    get url, params: { display_ids: [with_lead.display_id] }

    expect(response).to have_http_status(:unauthorized)
  end

  it 'returns the stage keyed by display_id and null for conversations without a lead' do
    get url, headers: agent.create_new_auth_token, params: { display_ids: [with_lead.display_id, without_lead.display_id] }

    expect(response).to have_http_status(:success)
    expect(response.parsed_body).to eq(
      with_lead.display_id.to_s => {
        'id' => stage.id, 'slug' => 'aguardando_atendimento_humano', 'name' => 'Aguardando equipe',
        'stage_type' => 'working', 'needs_human' => true
      },
      without_lead.display_id.to_s => nil
    )
  end
end
