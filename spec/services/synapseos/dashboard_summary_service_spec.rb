require 'rails_helper'

# CUSTOMIZAÇÃO_SYNAPSEOS: cobre o KPI "disparos hoje" (shoots_today) do
# dashboard executivo — contatos distintos que receberam ao menos uma outgoing
# hoje (boundary BRT), independente do filtro de período.
RSpec.describe Synapseos::DashboardSummaryService do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }

  def outgoing_to(contact, at:)
    conv = create(:conversation, account: account, inbox: inbox, contact: contact)
    create(:message, account: account, inbox: inbox, conversation: conv,
                     message_type: :outgoing, created_at: at)
  end

  describe '#call kpis[:shoots_today]' do
    it 'conta contatos DISTINTOS que receberam outgoing hoje' do
      c1 = create(:contact, account: account)
      c2 = create(:contact, account: account)
      now = Time.current
      outgoing_to(c1, at: now)
      outgoing_to(c1, at: now) # mesmo contato -> conta 1
      outgoing_to(c2, at: now)

      summary = described_class.new(account).call

      expect(summary[:kpis][:shoots_today]).to eq(2)
    end

    it 'não conta outgoings de dias anteriores' do
      contact = create(:contact, account: account)
      outgoing_to(contact, at: 2.days.ago)

      summary = described_class.new(account).call

      expect(summary[:kpis][:shoots_today]).to eq(0)
    end

    it 'não reage ao filtro de período (sempre hoje)' do
      contact = create(:contact, account: account)
      outgoing_to(contact, at: Time.current)

      # period_days curtíssimo não muda o "hoje"
      summary = described_class.new(account, period_days: 1).call

      expect(summary[:kpis][:shoots_today]).to eq(1)
    end
  end

  describe '#call dry_run (snapshot do n8n via CrmEvent)' do
    def snapshot!(meta, at: Time.current)
      Synapseos::CrmEvent.create!(account: account, event_type: 'dry_run_snapshot',
                                  metadata: meta, created_at: at)
    end

    it 'retorna nil quando não há snapshot hoje' do
      expect(described_class.new(account).call[:dry_run]).to be_nil
    end

    it 'pega o snapshot MAIS RECENTE de hoje (tarde sobre manhã)' do
      snapshot!({ 'scope' => 'manha', 'disparos' => [{ 'nome' => 'A', 'tel4' => '1111' }],
                  'followups' => [] }, at: 3.hours.ago)
      snapshot!({ 'scope' => 'tarde', 'disparos' => [{ 'nome' => 'B', 'tel4' => '2222' }],
                  'followups' => [{ 'nome' => 'C', 'tel4' => '3333' }] }, at: 1.minute.ago)

      dr = described_class.new(account).call[:dry_run]

      expect(dr[:scope]).to eq('tarde')
      expect(dr[:disparos_count]).to eq(1)
      expect(dr[:followups_count]).to eq(1)
      expect(dr[:disparos].first['nome']).to eq('B')
    end

    it 'ignora snapshot de dias anteriores' do
      snapshot!({ 'scope' => 'manha', 'disparos' => [{ 'nome' => 'X', 'tel4' => '9999' }] },
                at: 2.days.ago)
      expect(described_class.new(account).call[:dry_run]).to be_nil
    end
  end

  describe '#call previous_period' do
    it 'calcula os KPIs de período na janela de mesmo tamanho imediatamente anterior' do
      outgoing_to(create(:contact, account: account), at: 2.days.ago)
      outgoing_to(create(:contact, account: account), at: 10.days.ago)
      outgoing_to(create(:contact, account: account), at: 12.days.ago)
      outgoing_to(create(:contact, account: account), at: 30.days.ago) # fora das duas janelas

      summary = described_class.new(account, period_days: 7).call

      expect(summary[:kpis][:shoots_period]).to eq(1)
      expect(summary[:previous_period][:kpis][:shoots_period]).to eq(2)
    end
  end

  describe '#call funnel' do
    def incoming_in(conversation, at:)
      create(:message, account: account, inbox: inbox, conversation: conversation,
                       message_type: :incoming, created_at: at)
    end

    it 'conta disparos → responderam (incoming após a 1ª outgoing) → alertas → ganhos' do
      won = create(:synapseos_pipeline_stage, account: account, stage_type: 'won')
      replied = outgoing_to(create(:contact, account: account), at: 3.hours.ago).conversation
      incoming_in(replied, at: 2.hours.ago)
      silent = outgoing_to(create(:contact, account: account), at: 1.hour.ago).conversation
      incoming_in(silent, at: 2.hours.ago) # antes do disparo: não é resposta
      Synapseos::CrmEvent.create!(account: account, event_type: 'sales_alert_dispatched',
                                  conversation_id: replied.id, metadata: {})
      create(:synapseos_lead, conversation: replied, pipeline_stage_id: won.id)

      funnel = described_class.new(account).call[:funnel]

      expect(funnel).to eq(disparos: 2, responderam: 1, alertas: 1, ganhos: 1)
    end
  end
end
