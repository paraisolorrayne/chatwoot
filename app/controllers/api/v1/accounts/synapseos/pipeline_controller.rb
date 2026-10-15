class Api::V1::Accounts::Synapseos::PipelineController < Api::V1::Accounts::BaseController
  before_action :check_authorization

  def show
    ensure_default_stages
    @stages = ::Synapseos::PipelineStage.where(account_id: Current.account.id).ordered
    @leads = enriched_leads
    @last_messages = last_messages_by_conversation(@leads)
  end

  private

  # Tenta seedar. Se persistir vazio depois do seeder, tenta um fallback que
  # cria stages mínimos sem slug/description. Falhas são logadas em ERROR
  # (não warn) pra ficarem visíveis em prod.
  def ensure_default_stages
    ::Synapseos::EnsureDefaultStagesService.new(Current.account).call

    existing_count = ::Synapseos::PipelineStage.where(account_id: Current.account.id).count
    return if existing_count >= ::Synapseos::PipelineStage::DEFAULT_STAGES.size

    Rails.logger.error(
      "[Pipeline] account=#{Current.account.id} ainda tem #{existing_count}/#{::Synapseos::PipelineStage::DEFAULT_STAGES.size} stages após seeder; tentando fallback"
    )

    ::Synapseos::PipelineStage::DEFAULT_STAGES.each do |attrs|
      next if ::Synapseos::PipelineStage.where(account_id: Current.account.id, name: attrs[:name]).exists?

      payload = attrs.merge(account_id: Current.account.id)
      payload = payload.except(:slug) unless ::Synapseos::PipelineStage.column_names.include?('slug')
      payload = payload.except(:description) unless ::Synapseos::PipelineStage.column_names.include?('description')
      ::Synapseos::PipelineStage.create!(payload)
    rescue StandardError => e
      Rails.logger.error("[Pipeline] fallback seed account=#{Current.account.id} stage=#{attrs[:name]} falhou: #{e.class} #{e.message}")
    end
  end

  # CUSTOMIZAÇÃO_SYNAPSEOS: o card do board mostra quem atende (consultor ou bot
  # da inbox) e o último negócio; tudo pré-carregado pra não fazer N+1.
  def enriched_leads
    leads = ::Synapseos::Lead
            .where(account_id: Current.account.id)
            .includes(:deals, { contact: { avatar_attachment: :blob } }, { assignee: { avatar_attachment: :blob } },
                      conversation: [:contact, :assignee_agent_bot, { assignee: { avatar_attachment: :blob } },
                                     { inbox: { agent_bot_inbox: :agent_bot } }])
    leads = leads.where(pipeline_stage_id: params[:stage_id]) if params[:stage_id].present?
    leads.order(updated_at: :desc).limit(500)
  end

  # Última mensagem (não privada) de cada conversa em 2 queries. `unscope(:order)`
  # tira o default_scope de Message, que quebra o GROUP BY no Postgres.
  def last_messages_by_conversation(leads)
    conversation_ids = leads.map(&:conversation_id)
    return {} if conversation_ids.empty?

    last_ids = Message.where(conversation_id: conversation_ids).chat.unscope(:order).group(:conversation_id).maximum(:id)
    Message.where(id: last_ids.values).index_by(&:conversation_id)
  end

  def check_authorization
    authorize(User, :index?)
  end
end
