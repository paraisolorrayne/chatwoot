require 'rails_helper'

describe Synapseos::SupportRequestService do
  let(:support_phone) { '+5511991847629' }
  let(:account) { create(:account, name: 'Conta Suporte') }
  let(:user) { create(:user, account: account, role: :administrator, name: 'Operadora', email: 'op@example.com') }
  let(:request_id) { SecureRandom.uuid }
  let(:attrs) { { account: account, user: user, inbox: inbox, subject: 'Bot mudo', description: 'Conversa 42 sem resposta', request_id: request_id } }

  before do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:[]).with('FRONTEND_URL').and_return('https://chat.test')
    allow(ENV).to receive(:fetch).with('SYNAPSEOS_SUPPORT_TEMPLATE_NAME', nil).and_return(nil)
  end

  def perform(**overrides)
    described_class.new(**attrs, **overrides).perform
  end

  def avisa_channel
    create(:channel_whatsapp, account: account, provider: 'avisa',
                              provider_config: { 'api_key' => 'k', 'base_url' => 'https://avisa.test', 'skip_avisa_webhook_setup' => true },
                              sync_templates: false, validate_provider_config: false)
  end

  def official_channel(templates: [])
    create(:channel_whatsapp, account: account, provider: 'd360_cloud', message_templates: templates,
                              sync_templates: false, validate_provider_config: false)
  end

  describe '.phone_number' do
    it 'defaults to the SynapseOS support number' do
      expect(described_class.phone_number).to eq(support_phone)
    end

    it 'can be overridden by SYNAPSEOS_SUPPORT_PHONE' do
      allow(ENV).to receive(:fetch).with('SYNAPSEOS_SUPPORT_PHONE', support_phone).and_return('+5511900000000')
      expect(described_class.phone_number).to eq('+5511900000000')
    end
  end

  context 'with a non-official provider (Avisa)' do
    let(:inbox) { avisa_channel.inbox }

    it 'creates an outgoing message to the support contact through the account channel' do
      message = perform

      expect(message).to be_persisted
      expect(message).to be_outgoing
      expect(message).not_to be_private
      expect(message.sender).to eq(user)
      expect(message.inbox).to eq(inbox)
      expect(message.conversation.contact.phone_number).to eq(support_phone)
      expect(message.conversation.contact_inbox.source_id).to eq(support_phone.delete('+'))
    end

    it 'identifies the account, requester, channel and protocol in the body' do
      content = perform.content

      expect(content).to include('Bot mudo')
      expect(content).to include("Conta: #{account.name} (##{account.id})")
      expect(content).to include('Solicitante: Operadora (op@example.com)')
      expect(content).to include(inbox.channel.phone_number)
      expect(content).to include("Protocolo: #{request_id}")
      expect(content).to end_with('Conversa 42 sem resposta')
    end

    it 'flags the message so the history can find it and assigns the conversation to the requester' do
      message = perform

      expect(message.additional_attributes)
        .to include('synapseos_support' => true, 'support_request_id' => request_id, 'support_subject' => 'Bot mudo')
      expect(message.additional_attributes).not_to have_key('template_params')
      expect(message.conversation.assignee).to eq(user)
      expect(message.conversation).to be_open
      expect(described_class.requests(account, inbox.id)).to contain_exactly(message)
    end

    it 'does not send a duplicate when the same protocol is retried' do
      first = perform

      expect { perform }.not_to change(Message, :count)
      expect(perform).to eq(first)
    end

    it 'reuses the support conversation for new protocols instead of opening one per request' do
      first = perform
      second = perform(request_id: SecureRandom.uuid, subject: 'Outro problema')

      expect(second).not_to eq(first)
      expect(second.conversation).to eq(first.conversation)
      expect(described_class.requests(account, inbox.id).count).to eq(2)
    end

    it 'rejects blank or oversized input before touching the database' do
      expect { perform(subject: '') }.to raise_error(ActiveModel::ValidationError)
      expect { perform(description: 'x' * 3001) }.to raise_error(ActiveModel::ValidationError)
      expect { perform(request_id: 'not-a-uuid') }.to raise_error(ActiveModel::ValidationError)
      expect(Message.count).to eq(0)
      expect(Conversation.count).to eq(0)
    end
  end

  context 'with an official provider outside the reply window' do
    let(:inbox) { official_channel.inbox }

    it 'refuses with support_window_closed and creates nothing when no template is configured' do
      expect { perform }.to raise_error(ActiveModel::ValidationError) { |error|
        expect(error.model.errors.added?(:base, :support_window_closed)).to be(true)
      }
      expect(Message.count).to eq(0)
    end

    it 'refuses when the configured template is not approved on the channel' do
      allow(ENV).to receive(:fetch).with('SYNAPSEOS_SUPPORT_TEMPLATE_NAME', nil).and_return('suporte')
      inbox.channel.update!(message_templates: [{ 'name' => 'suporte', 'language' => 'pt_BR', 'status' => 'PENDING' }])

      expect { perform(inbox: inbox.reload) }.to raise_error(ActiveModel::ValidationError)
      expect(Message.count).to eq(0)
    end

    it 'sends the approved template with the request as the single body parameter' do
      allow(ENV).to receive(:fetch).with('SYNAPSEOS_SUPPORT_TEMPLATE_NAME', nil).and_return('suporte')
      allow(ENV).to receive(:fetch).with('SYNAPSEOS_SUPPORT_TEMPLATE_LANGUAGE', 'pt_BR').and_return('pt_BR')
      inbox.channel.update!(message_templates: [{ 'name' => 'suporte', 'language' => 'pt_BR', 'status' => 'approved', 'namespace' => 'ns' }])

      message = perform(inbox: inbox.reload)
      params = message.additional_attributes['template_params']

      expect(params).to include('name' => 'suporte', 'language' => 'pt_BR', 'namespace' => 'ns')
      expect(params.dig('processed_params', 'body', '1')).to include('Bot mudo', 'Conversa 42 sem resposta')
      expect(params.dig('processed_params', 'body', '1')).not_to include("\n")
    end

    it 'truncates the template parameter to the Meta limit while keeping the full text in the message' do
      allow(ENV).to receive(:fetch).with('SYNAPSEOS_SUPPORT_TEMPLATE_NAME', nil).and_return('suporte')
      inbox.channel.update!(message_templates: [{ 'name' => 'suporte', 'language' => 'pt_BR', 'status' => 'approved' }])

      message = perform(inbox: inbox.reload, description: 'x' * 3000)
      param = message.additional_attributes.dig('template_params', 'processed_params', 'body', '1')

      expect(param.length).to eq(described_class::TEMPLATE_PARAM_MAX_LENGTH)
      expect(param).to end_with('…')
      expect(message.content).to end_with('x' * 3000)
    end
  end

  context 'with an official provider inside the reply window' do
    let(:inbox) { official_channel.inbox }
    let(:contact) { create(:contact, account: account, phone_number: support_phone) }
    let(:contact_inbox) { create(:contact_inbox, contact: contact, inbox: inbox, source_id: support_phone.delete('+')) }
    let!(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact, contact_inbox: contact_inbox) }

    before do
      create(:message, account: account, inbox: inbox, conversation: conversation, message_type: :incoming, sender: contact)
    end

    it 'sends a session message in the existing conversation without a template' do
      message = perform

      expect(message.conversation).to eq(conversation)
      expect(message.additional_attributes).not_to have_key('template_params')
    end
  end
end
