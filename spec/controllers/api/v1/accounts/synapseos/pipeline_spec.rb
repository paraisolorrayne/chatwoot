require 'rails_helper'

RSpec.describe 'Synapseos Pipeline API', type: :request do
  let(:account) { create(:account) }
  let!(:admin) { create(:user, account: account, role: :administrator) }
  let(:inbox) { create(:inbox, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }
  let!(:stage) do
    create(:synapseos_pipeline_stage, account: account, slug: 'aguardando_atendimento_humano',
                                      name: 'Aguardando equipe', stage_type: 'working')
  end

  describe 'GET /api/v1/accounts/:account_id/synapseos/pipeline' do
    let(:url) { "/api/v1/accounts/#{account.id}/synapseos/pipeline" }

    before do
      create(:agent_bot_inbox, inbox: inbox, agent_bot: create(:agent_bot, account: account, name: 'Elisa'))
      create(:message, conversation: conversation, account: account, inbox: inbox, content: 'Quero ver o Q5', message_type: :incoming)
      create(:synapseos_lead, account: account, conversation: conversation, pipeline_stage: stage,
                              metadata: { 'modelo_interesse' => 'Q5', 'loss_reason' => 'Comprou da concorrência' })
    end

    it 'returns stage slugs and the enriched lead card' do
      get url, headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      body = response.parsed_body
      expect(body['stages'].pluck('slug')).to include('aguardando_atendimento_humano')

      lead = body['leads'].first
      expect(lead['conversation_display_id']).to eq(conversation.display_id)
      expect(lead['modelo_interesse']).to eq('Q5')
      expect(lead['motivo']).to eq('Comprou da concorrência')
      expect(lead['handler']).to include('kind' => 'bot', 'name' => 'Elisa')
      expect(lead['last_message']['content']).to eq('Quero ver o Q5')
    end

    it 'prefers the human assignee over the inbox bot' do
      conversation.update!(assignee: admin)

      get url, headers: admin.create_new_auth_token, as: :json

      expect(response.parsed_body['leads'].first['handler']).to include('kind' => 'user', 'id' => admin.id)
    end
  end

  describe 'PATCH /api/v1/accounts/:account_id/synapseos/leads/:id' do
    let(:lead) { create(:synapseos_lead, account: account, conversation: conversation) }

    it 'stores the loss reason chosen on the board' do
      patch "/api/v1/accounts/#{account.id}/synapseos/leads/#{lead.id}",
            headers: admin.create_new_auth_token,
            params: { lead: { pipeline_stage_id: stage.id, motivo: 'Comprou da concorrência' } },
            as: :json

      expect(response).to have_http_status(:success)
      expect(lead.reload.motivo).to eq('Comprou da concorrência')
    end
  end
end
