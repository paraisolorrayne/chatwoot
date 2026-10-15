module Synapseos
  class DashboardSummaryService # rubocop:disable Metrics/ClassLength
    def initialize(account, period_days: 30)
      @account = account
      @period_days = period_days
      @range = period_days.days.ago.beginning_of_day..Time.current
      # CUSTOMIZAÇÃO_SYNAPSEOS: janela de mesmo tamanho imediatamente antes do
      # período selecionado (fim exclusivo pra não contar o limite duas vezes).
      @previous_range = (@range.first - (@range.last - @range.first))...@range.first
    end

    def call
      {
        period_days: @period_days,
        period_start: @range.first,
        period_end: @range.last,
        kpis: kpis,
        # CUSTOMIZAÇÃO_SYNAPSEOS: mesmos KPIs de período na janela anterior
        # (para o delta "vs. período anterior" dos cards).
        previous_period: {
          period_start: @previous_range.first,
          period_end: @previous_range.last,
          kpis: period_kpis(@previous_range)
        },
        funnel: funnel,
        daily: daily_breakdown,
        recent_events: recent_events,
        dry_run: dry_run_snapshot
      }
    end

    # Preview READ-ONLY do dia (gravado pelo n8n via CrmEvent 'dry_run_snapshot'
    # às 08:00/13:30). Pega o snapshot MAIS RECENTE de hoje (BRT) — de manhã
    # mostra o plano do dia; à tarde, o restante. nil se ainda não rodou hoje.
    def dry_run_snapshot
      tz = ActiveSupport::TimeZone['America/Sao_Paulo']
      ev = ::Synapseos::CrmEvent
           .where(account_id: @account.id, event_type: 'dry_run_snapshot')
           .where('created_at >= ?', tz.now.beginning_of_day)
           .order(created_at: :desc)
           .first
      return nil if ev.nil?

      meta = ev.metadata.is_a?(Hash) ? ev.metadata : {}
      disparos = meta['disparos'].is_a?(Array) ? meta['disparos'] : []
      followups = meta['followups'].is_a?(Array) ? meta['followups'] : []
      {
        scope: meta['scope'],
        generated_at: meta['generated_at'] || ev.created_at.iso8601,
        disparos_count: meta['disparos_count'] || disparos.size,
        followups_count: meta['followups_count'] || followups.size,
        disparos: disparos,
        followups: followups
      }
    end

    def recent_events
      # ATIVIDADE RECENTE — somente alertas APROVADOS no Slack
      # (sales_alert_approved), criados pelo webhook de aprovação. Deduplica
      # por conversa (1 por conversa, o mais recente). O NOME vem do
      # metadata['nome'] capturado no momento da aprovação — NÃO da associação
      # conversation (que resolve por id interno e colide com display_id).
      # CrmEvent.conversation_id guarda o DISPLAY id (vem da API do Chatwoot via
      # n8n) — é ele que a rota da conversa espera.
      ::Synapseos::CrmEvent
        .where(account_id: @account.id, event_type: 'sales_alert_approved', created_at: @range)
        .order(created_at: :desc)
        .limit(50)
        .uniq { |e| e.conversation_id || "ev-#{e.id}" }
        .first(10)
        .map { |e| serialize_alert(e) }
    end

    private

    def serialize_alert(event)
      meta = event.metadata.is_a?(Hash) ? event.metadata : {}
      {
        id: event.id,
        event_type: event.event_type,
        conversation_id: event.conversation_id,
        # Sem fallback textual: o frontend traduz o "a definir" / "—".
        contact_name: meta['nome'].presence,
        modelo_interesse: meta['modelo_interesse'].presence,
        tipo: meta['tipo'],
        metadata: event.metadata,
        created_at: event.created_at
      }
    end

    def kpis
      {
        leads: leads_scope.count,
        # Negócios ganhos = leads na coluna "ganho" da pipeline (stage_type
        # 'won', ex: 'venda'). Fonte de verdade do consultor, não os alertas.
        # Estado atual (não reage ao período, sem histórico de entrada no stage).
        deals_won: won_stage_leads_count,
        # Negócios perdidos = leads na coluna "perdido" da pipeline (stage_type
        # 'lost', ex: 'encerrado'). Simétrico com deals_won e MESMA fonte que a
        # pipeline mostra — antes contava events lead_blocked (histórico) e
        # divergia da coluna Perdidos.
        deals_lost: lost_stage_leads_count,
        messages_received: messages.where(message_type: :incoming).count,
        # CUSTOMIZAÇÃO_SYNAPSEOS: "mensagens disparadas" no domínio Synapseos
        # significa "contatos distintos que receberam pelo menos uma outgoing
        # no período" — não a soma bruta de outgoing.
        messages_sent: current_period_kpis[:shoots_period],
        # `shoots_month` mantido por backcompat (acumulativo do mês corrente).
        shoots_month: shoots_month_count,
        # DISPAROS NO DIA (hoje, BRT) — contatos distintos que receberam ao
        # menos uma outgoing hoje. NÃO reage ao filtro de período.
        shoots_today: shoots_today_count,
        # ELISA → EQUIPE HOJE (BRT): alertas únicos de hoje. NÃO reage ao filtro.
        bot_takeovers_today: unique_alert_conversations(today_range),
        # human_rescues mantido por backcompat; frontend não exibe mais.
        human_rescues: events_of('human_rescue').count,
        ai_responses: messages.where(sender_type: 'AgentBot').count,
        # Agendamentos = leads na coluna "Aguardando visita" da pipeline
        # (fonte de verdade do consultor), não eventos appointment_confirmed.
        appointments: aguardando_visita_leads_count
      }.merge(current_period_kpis)
    end

    def current_period_kpis
      @current_period_kpis ||= period_kpis(@range)
    end

    # KPIs que reagem ao filtro de período — calculados para o período atual e
    # para o anterior (delta dos cards).
    def period_kpis(range)
      shoots = outgoing_distinct_contacts(range)
      alerts = unique_alert_conversations(range)
      {
        # DISPAROS NO PERÍODO = contatos distintos que receberam ao menos uma
        # outgoing no período.
        shoots_period: shoots,
        # ELISA → EQUIPE: conversas distintas com alerta de venda
        # (sales_alert_dispatched) = handoffs pra consultor humano. Mesma fonte
        # da lista de "Últimos alertas" — invariante: lista com items ⇒ KPI > 0.
        bot_takeovers: alerts,
        # Receita em negociação = somatório de preco_brl_a_partir armazenado no
        # metadata do sales_alert_dispatched (n8n busca o preço de referência do
        # veículo via audi_knowledge_query e grava no event metadata).
        revenue: sales_alert_revenue(events_of('sales_alert_dispatched', range)),
        # Qualificação = alertas únicos / disparos no período (%). Mede quantos
        # contatos abordados viraram alerta de venda (handoff pra humano).
        conversion_rate: shoots.zero? ? 0.0 : ((alerts.to_f / shoots) * 100).round(2)
      }
    end

    # Funil do período, em contatos/conversas distintos:
    # - disparos: contatos que receberam ao menos uma outgoing no período;
    # - responderam: desses, os que mandaram ao menos uma incoming no período
    #   DEPOIS da primeira outgoing que receberam no período;
    # - alertas: conversas com alerta de venda no período (mesmo KPI do card);
    # - ganhos: leads hoje na coluna "ganho" cujo contato foi abordado no período.
    def funnel
      {
        disparos: current_period_kpis[:shoots_period],
        responderam: replied_contacts_count(@range),
        alertas: current_period_kpis[:bot_takeovers],
        ganhos: ::Synapseos::Lead.where(account_id: @account.id, pipeline_stage_id: stage_ids('won'),
                                        contact_id: outgoing_messages(@range).select('conversations.contact_id'))
                                 .count
      }
    end

    def replied_contacts_count(range)
      first_outgoing = outgoing_messages(range)
                       .group('conversations.contact_id')
                       .select('conversations.contact_id, MIN(messages.created_at) AS first_out_at')
      # Joins em string: um `joins(:conversation)` aqui seria apelidado pelo AR
      # (o subselect também cita `conversations`).
      ::Message.where(account_id: @account.id, created_at: range, message_type: :incoming)
               .joins('INNER JOIN conversations ON conversations.id = messages.conversation_id')
               .joins("INNER JOIN (#{first_outgoing.to_sql}) first_out ON first_out.contact_id = conversations.contact_id")
               .where('messages.created_at > first_out.first_out_at')
               .reorder(nil)
               .distinct
               .count('conversations.contact_id')
    end

    def unique_alert_conversations(range)
      events_of('sales_alert_dispatched', range).distinct.count('conversation_id')
    end

    # Soma preco_brl_a_partir do metadata dos sales_alert_dispatched.
    # Pega 1 alerta por conversa (o mais recente) pra evitar dupla contagem.
    # Defensivo contra metadata mal formado (não-numérico, ausente).
    def sales_alert_revenue(scope)
      # Exclui eventos órfãos (conversation_id nulo): não são atribuíveis a
      # uma conversa e o DISTINCT ON colapsaria todos num único grupo nulo,
      # contando 1 preço fantasma. Alinha com `deals_won`/`bot_takeovers`,
      # que usam COUNT(DISTINCT conversation_id) — o qual já ignora nulos.
      latest_per_conv = scope.where.not(conversation_id: nil)
                             .select('DISTINCT ON (conversation_id) conversation_id, metadata, created_at')
                             .order('conversation_id, created_at DESC')
      latest_per_conv.sum do |ev|
        meta = ev.metadata.is_a?(Hash) ? ev.metadata : {}
        price = meta['preco_brl_a_partir'] || meta[:preco_brl_a_partir]
        price.to_f
      end
    rescue StandardError => e
      Rails.logger.warn("[DashboardSummaryService] revenue calc failed: #{e.message}")
      0.0
    end

    def daily_breakdown
      days = (0...@period_days).map { |offset| (@period_days - 1 - offset).days.ago.to_date }
      msgs_in = messages.where(message_type: :incoming).reorder(nil).group('DATE(created_at)').count
      msgs_out_distinct = outgoing_distinct_contacts_by_day
      # Daily takeovers = alertas de venda únicos por dia (mesma fonte do KPI).
      # group por DATE + conversation_id distinto evita dupla contagem se a
      # mesma conv gerou 2 alertas no mesmo dia.
      takeovers = events_of('sales_alert_dispatched')
                  .where.not(conversation_id: nil)
                  .reorder(nil)
                  .group('DATE(created_at)')
                  .distinct
                  .count('conversation_id')
      ai_resp = messages.where(sender_type: 'AgentBot').reorder(nil).group('DATE(created_at)').count

      days.map do |day|
        {
          date: day.iso8601,
          messages_received: msgs_in[day].to_i,
          messages_sent: msgs_out_distinct[day].to_i,
          bot_takeovers: takeovers[day].to_i,
          ai_responses: ai_resp[day].to_i
        }
      end
    end

    # CUSTOMIZAÇÃO_SYNAPSEOS: count of distinct contacts that received at
    # least one outgoing message inside ``range``. Uses conversation.contact_id
    # because outgoing messages always belong to a conversation.
    def outgoing_distinct_contacts(range)
      outgoing_messages(range).distinct.count('conversations.contact_id')
    end

    def outgoing_messages(range)
      ::Message.where(account_id: @account.id, created_at: range, message_type: :outgoing)
               .joins(:conversation)
               .reorder(nil)
    end

    # Daily version — returns { Date => count } using PostgreSQL
    # DATE(messages.created_at) grouping with distinct contact_id per day.
    def outgoing_distinct_contacts_by_day
      outgoing_messages(@range)
        .group(Arel.sql('DATE(messages.created_at)'))
        .distinct
        .count('conversations.contact_id')
    end

    def leads_scope
      ::Synapseos::Lead.where(account_id: @account.id, created_at: @range)
    end

    # Negócios ganhos = leads atualmente em qualquer stage do tipo 'won'
    # (coluna "ganho" da pipeline). Contagem corrente (não filtra período),
    # pois o pipeline é fonte de verdade do estado atual.
    def won_stage_leads_count
      ::Synapseos::Lead.where(account_id: @account.id, pipeline_stage_id: stage_ids('won')).count
    end

    # Negócios perdidos = leads na coluna "perdido" da pipeline (stage_type
    # 'lost'). Mesma fonte que a coluna Perdidos do board — simétrico ao won.
    def lost_stage_leads_count
      ::Synapseos::Lead.where(account_id: @account.id, pipeline_stage_id: stage_ids('lost')).count
    end

    def stage_ids(stage_type)
      ::Synapseos::PipelineStage.where(account_id: @account.id, stage_type: stage_type).select(:id)
    end

    # Agendamentos = leads atualmente na coluna "Aguardando visita".
    def aguardando_visita_leads_count
      stage = ::Synapseos::PipelineStage.find_by(account_id: @account.id, slug: 'aguardando_visita')
      return 0 unless stage

      ::Synapseos::Lead.where(account_id: @account.id, pipeline_stage_id: stage.id).count
    end

    # Disparos feitos no MÊS corrente = contatos distintos que receberam ao
    # menos uma mensagem outgoing no mês (mesma métrica de `shoots_period`,
    # mas fixa no mês — não reage ao filtro). NÃO conta leads importados:
    # "disparo feito" = mensagem efetivamente enviada.
    def shoots_month_count
      month_range = Time.current.beginning_of_month..Time.current
      outgoing_distinct_contacts(month_range)
    end

    # Disparos feitos HOJE (dia corrente em BRT) = contatos distintos que
    # receberam ao menos uma outgoing hoje. Boundary em America/Sao_Paulo pra
    # bater com o dia operacional (disparos rodam 8h-18h BRT); senão um disparo
    # às 22h BRT cairia no dia seguinte em UTC.
    def shoots_today_count
      outgoing_distinct_contacts(today_range)
    end

    def today_range
      ActiveSupport::TimeZone['America/Sao_Paulo'].now.beginning_of_day..Time.current
    end

    def messages
      ::Message.where(account_id: @account.id, created_at: @range)
    end

    def events_of(type, range = @range)
      ::Synapseos::CrmEvent.where(account_id: @account.id, event_type: type, created_at: range)
    end
  end
end
