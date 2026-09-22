require 'rails_helper'

RSpec.describe 'Synapseos Support Requests API', type: :request do
  let(:account) { create(:account) }
  let!(:admin) { create(:user, account: account, role: :administrator, name: 'Admin') }
  let!(:agent) { create(:user, account: account, role: :agent) }
  let(:avisa_config) { { 'api_key' => 'k', 'base_url' => 'https://avisa.test', 'skip_avisa_webhook_setup' => true } }
  let(:channel) do
    create(:channel_whatsapp, account: account, provider: 'avisa', provider_config: avisa_config,
                              sync_templates: false, validate_provider_config: false)
  end
  let(:inbox) { channel.inbox }
  let(:url) { "/api/v1/accounts/#{account.id}/synapseos/support_requests" }
  let(:request_id) { SecureRandom.uuid }
  let(:payload) { { support_request: { inbox_id: inbox.id, subject: 'Bot mudo', description: 'Conversa 42', request_id: request_id } } }

  before do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with('FRONTEND_URL').and_return('https://chat.test')
  end

  describe 'GET /api/v1/accounts/:account_id/synapseos/support_requests' do
    it 'returns unauthorized when unauthenticated' do
      get url, as: :json
      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns unauthorized for a user from another account' do
      outsider = create(:user, account: create(:account), role: :administrator)
      get url, headers: outsider.create_new_auth_token, as: :json
      expect(response).to have_http_status(:unauthorized)
    end

    it 'lists only WhatsApp channels the user can access, the destination and the history' do
      whatsapp_inbox = inbox
      create(:inbox, account: account)
      get url, headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      body = response.parsed_body
      expect(body['destination']).to eq(Synapseos::SupportRequestService.phone_number)
      expect(body['inboxes']).to eq([{ 'id' => whatsapp_inbox.id, 'name' => whatsapp_inbox.name, 'phone_number' => channel.phone_number }])
      expect(body['requests']).to eq([])
    end

    it 'returns no channel for an agent who is not a member of the WhatsApp inbox' do
      get url, headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['inboxes']).to eq([])
    end
  end

  describe 'POST /api/v1/accounts/:account_id/synapseos/support_requests' do
    it 'creates the request, reports it as queued and ignores a client-supplied destination' do
      post url, headers: admin.create_new_auth_token,
                params: payload.deep_merge(support_request: { destination: '+5500000000000' }), as: :json

      expect(response).to have_http_status(:created)
      body = response.parsed_body
      expect(body).to include('request_id' => request_id, 'subject' => 'Bot mudo', 'status' => 'queued',
                              'sender_name' => 'Admin', 'inbox_name' => inbox.name)
      message = Message.find(body['id'])
      expect(message.conversation.contact.phone_number).to eq(Synapseos::SupportRequestService.phone_number)
      expect(body['conversation_id']).to eq(message.conversation.display_id)
    end

    it 'is idempotent for the same protocol' do
      post url, headers: admin.create_new_auth_token, params: payload, as: :json
      first_id = response.parsed_body['id']

      expect { post url, headers: admin.create_new_auth_token, params: payload, as: :json }.not_to change(Message, :count)
      expect(response).to have_http_status(:created)
      expect(response.parsed_body['id']).to eq(first_id)
    end

    it 'shows the request in the history with delivery status' do
      post url, headers: admin.create_new_auth_token, params: payload, as: :json
      Message.find(response.parsed_body['id']).update!(status: :failed, external_error: 'Provider unavailable')

      get url, headers: admin.create_new_auth_token, as: :json

      history = response.parsed_body['requests'].map { |item| item.slice('request_id', 'status') }
      expect(history).to eq([{ 'request_id' => request_id, 'status' => 'failed' }])
    end

    it 'rejects invalid input with invalid_request' do
      post url, headers: admin.create_new_auth_token,
                params: { support_request: { inbox_id: inbox.id, subject: '', description: '', request_id: 'x' } }, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['error']).to eq('invalid_request')
    end

    it 'rejects a WhatsApp inbox the agent cannot access' do
      post url, headers: agent.create_new_auth_token, params: payload, as: :json
      expect(response).to have_http_status(:not_found)
    end

    it 'rejects an inbox that belongs to another account' do
      foreign = create(:channel_whatsapp, account: create(:account), provider: 'avisa', provider_config: avisa_config,
                                          sync_templates: false, validate_provider_config: false)
      post url, headers: admin.create_new_auth_token,
                params: payload.deep_merge(support_request: { inbox_id: foreign.inbox.id }), as: :json
      expect(response).to have_http_status(:not_found)
    end

    it 'answers window_closed for an official channel without an approved template' do
      official = create(:channel_whatsapp, account: account, provider: 'd360_cloud',
                                           sync_templates: false, validate_provider_config: false)
      post url, headers: admin.create_new_auth_token,
                params: payload.deep_merge(support_request: { inbox_id: official.inbox.id }), as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['error']).to eq('window_closed')
      expect(Message.count).to eq(0)
    end
  end
end
