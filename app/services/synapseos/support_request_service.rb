# Uses the account's own WhatsApp channel and the regular delivery pipeline.
# The request UUID makes retries after a network timeout safe.
class Synapseos::SupportRequestService
  include ActiveModel::Model

  TEMPLATE_PARAM_MAX_LENGTH = 1024

  attr_accessor :account, :user, :inbox, :subject, :description, :request_id

  validates :subject, presence: true, length: { maximum: 120 }
  validates :description, presence: true, length: { maximum: 3000 }
  validates :request_id, format: { with: /\A[0-9a-f-]{36}\z/i }

  def self.phone_number
    ENV.fetch('SYNAPSEOS_SUPPORT_PHONE', '+5511991847629')
  end

  def self.requests(account, inbox_ids)
    account.messages.outgoing.where(inbox_id: inbox_ids)
           .where("additional_attributes ->> 'synapseos_support' = 'true'")
  end

  def perform
    validate!
    account.with_lock do
      existing = self.class.requests(account, inbox.id)
                     .find_by("additional_attributes ->> 'support_request_id' = ?", request_id)
      next existing if existing

      conversation = support_conversation
      template_params = template_for(conversation)
      conversation.messages.create!(
        account: account, inbox: inbox, sender: user, message_type: :outgoing,
        content: message_content,
        additional_attributes: {
          synapseos_support: true, support_request_id: request_id,
          support_subject: subject, template_params: template_params
        }.compact
      )
    end
  end

  private

  def support_conversation
    contact_inbox = support_contact_inbox
    conversation = contact_inbox.conversations.order(created_at: :desc).first || account.conversations.create!(
      inbox: inbox, contact: contact_inbox.contact, contact_inbox: contact_inbox,
      assignee: user, status: :open, additional_attributes: { synapseos_support: true }
    )
    conversation.update!(status: :open, assignee: user) if conversation.pending?
    conversation
  end

  def support_contact_inbox
    existing = inbox.contact_inboxes.find_by(source_id: self.class.phone_number.delete('+'))
    return existing if existing

    contact = account.contacts.find_or_create_by!(phone_number: self.class.phone_number) { |record| record.name = 'Suporte' }
    ContactInboxBuilder.new(contact: contact, inbox: inbox, source_id: nil).perform
  end

  def template_for(conversation)
    return if Whatsapp::SendOnWhatsappService::NON_OFFICIAL_PROVIDERS.include?(inbox.channel.provider) || conversation.can_reply?

    template = approved_template
    unless template
      errors.add(:base, :support_window_closed)
      raise ActiveModel::ValidationError, self
    end
    {
      name: template['name'], language: template['language'], namespace: template['namespace'],
      processed_params: { body: { '1' => template_body_param } }
    }.compact
  end

  # Meta rejects body parameters with line breaks, runs of 4+ spaces or more
  # than TEMPLATE_PARAM_MAX_LENGTH characters, so the request is flattened and
  # truncated only on the template path. The full text still lands in the
  # Chatwoot conversation.
  def template_body_param
    flat = message_content.gsub(/\s+/, ' ').strip
    flat.length > TEMPLATE_PARAM_MAX_LENGTH ? "#{flat[0, TEMPLATE_PARAM_MAX_LENGTH - 1]}…" : flat
  end

  def approved_template
    name = ENV.fetch('SYNAPSEOS_SUPPORT_TEMPLATE_NAME', nil)
    return if name.blank?

    language = ENV.fetch('SYNAPSEOS_SUPPORT_TEMPLATE_LANGUAGE', 'pt_BR')
    Array(inbox.channel.message_templates).find do |item|
      item['name'] == name && item['language'] == language && item['status'].to_s.casecmp?('approved')
    end
  end

  def message_content
    [
      "Pedido de suporte — #{subject}",
      "Conta: #{account.name} (##{account.id})",
      "Solicitante: #{user.name} (#{user.email})",
      "Canal: #{inbox.name} — #{inbox.channel.phone_number}",
      "Protocolo: #{request_id}",
      '', description
    ].join("\n")
  end
end
