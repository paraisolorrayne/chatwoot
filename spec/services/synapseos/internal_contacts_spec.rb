require 'rails_helper'

describe Synapseos::InternalContacts do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }

  before do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with('SYNAPSEOS_INTERNAL_PHONES', '').and_return(' +55 (34) 99130-4735 , 5511900000000')
  end

  def conversation_for(phone, source_id: nil, additional_attributes: {})
    contact = create(:contact, account: account, phone_number: phone)
    contact_inbox = create(:contact_inbox, contact: contact, inbox: inbox, source_id: source_id || phone.delete('+'))
    create(:conversation, account: account, inbox: inbox, contact: contact, contact_inbox: contact_inbox,
                          additional_attributes: additional_attributes)
  end

  describe '.phones' do
    it 'normalizes the env list and always includes the support number' do
      expect(described_class.phones).to contain_exactly('5534991304735', '5511900000000', '5511991847629')
    end
  end

  describe '.internal?' do
    it 'is true for the support number and for numbers in SYNAPSEOS_INTERNAL_PHONES' do
      expect(described_class.internal?(conversation_for('+5511991847629'))).to be(true)
      expect(described_class.internal?(conversation_for('+5534991304735'))).to be(true)
    end

    it 'matches by contact_inbox source_id when the contact has no phone' do
      contact = create(:contact, account: account, phone_number: nil)
      contact_inbox = create(:contact_inbox, contact: contact, inbox: inbox, source_id: '5511991847629')
      conversation = create(:conversation, account: account, inbox: inbox, contact: contact, contact_inbox: contact_inbox)
      expect(described_class.internal?(conversation)).to be(true)
    end

    it 'is true for conversations opened by the support center regardless of number' do
      expect(described_class.internal?(conversation_for('+5534999990000', additional_attributes: { 'synapseos_support' => true }))).to be(true)
    end

    it 'is false for ordinary leads and for nil' do
      expect(described_class.internal?(conversation_for('+5534999990000'))).to be(false)
      expect(described_class.internal?(nil)).to be(false)
    end
  end
end
