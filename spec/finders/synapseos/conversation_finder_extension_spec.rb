require 'rails_helper'

describe Synapseos::ConversationFinderExtension do
  let!(:account) { create(:account) }
  let!(:admin) { create(:user, account: account, role: :administrator) }
  let!(:inbox) { create(:inbox, account: account, enable_auto_assignment: false) }
  let!(:handoff_stage) do
    create(:synapseos_pipeline_stage, account: account, slug: 'aguardando_atendimento_humano', stage_type: 'working')
  end
  let!(:bot_stage) { create(:synapseos_pipeline_stage, account: account, slug: 'em_atendimento', stage_type: 'open') }
  let!(:waiting_less) { create(:conversation, account: account, inbox: inbox) }
  let!(:waiting_longer) { create(:conversation, account: account, inbox: inbox) }

  before do
    waiting_less.update!(waiting_since: 10.minutes.ago)
    waiting_longer.update!(waiting_since: 2.hours.ago)
    create(:synapseos_lead, conversation: waiting_less, pipeline_stage: handoff_stage)
    create(:synapseos_lead, conversation: waiting_longer, pipeline_stage: handoff_stage)
    create(:synapseos_lead, conversation: create(:conversation, account: account, inbox: inbox), pipeline_stage: bot_stage)
    create(:conversation, account: account, inbox: inbox)
    Current.account = account
  end

  it 'lists only conversations waiting for a human, longest wait first' do
    result = ConversationFinder.new(admin, { assignee_type: 'needs_human' }).perform

    expect(result[:conversations].map(&:id)).to eq([waiting_longer.id, waiting_less.id])
    expect(result[:count]).to include(all_count: 4, needs_human_count: 2)
  end

  it 'falls back to working stages when the account has no handoff stage' do
    handoff_stage.update!(slug: 'proposta')

    expect(ConversationFinder.new(admin, {}).perform_meta_only[:count][:needs_human_count]).to eq(2)
  end
end
