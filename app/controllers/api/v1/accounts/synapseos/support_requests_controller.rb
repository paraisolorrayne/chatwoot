class Api::V1::Accounts::Synapseos::SupportRequestsController < Api::V1::Accounts::BaseController
  before_action :require_account_user

  def index
    render json: {
      destination: ::Synapseos::SupportRequestService.phone_number,
      inboxes: support_inboxes.map { |inbox| { id: inbox.id, name: inbox.name, phone_number: inbox.channel.phone_number } },
      requests: requests.includes(:sender, :conversation, :inbox).order(created_at: :desc).limit(50).map { |message| serialize(message) }
    }
  end

  def create
    inbox = support_inboxes.find(request_params[:inbox_id])
    service = ::Synapseos::SupportRequestService.new(
      **request_params.except(:inbox_id).to_h.symbolize_keys,
      account: Current.account, user: current_user, inbox: inbox
    )
    render json: serialize(service.perform), status: :created
  rescue ActiveModel::ValidationError => e
    code = e.model.errors.added?(:base, :support_window_closed) ? 'window_closed' : 'invalid_request'
    render json: { error: code }, status: :unprocessable_entity
  end

  private

  def require_account_user
    raise Pundit::NotAuthorizedError unless current_user && Current.account_user
  end

  def support_inboxes
    current_user.assigned_inboxes.where(account_id: Current.account.id, channel_type: 'Channel::Whatsapp').includes(:channel)
  end

  def requests
    ::Synapseos::SupportRequestService.requests(Current.account, support_inboxes.select(:id))
  end

  def request_params
    params.require(:support_request).permit(:inbox_id, :subject, :description, :request_id)
  end

  def serialize(message)
    {
      id: message.id, request_id: message.additional_attributes['support_request_id'],
      subject: message.additional_attributes['support_subject'],
      status: delivery_status(message),
      created_at: message.created_at, sender_name: message.sender&.name,
      inbox_name: message.inbox.name, conversation_id: message.conversation.display_id
    }
  end

  def delivery_status(message)
    return 'failed' if message.failed?

    message.source_id.present? ? message.status : 'queued'
  end
end
