<script setup>
// CUSTOMIZAÇÃO_SYNAPSEOS: card do lead no topo do painel da conversa — etapa
// (com troca de etapa), interesse, horizonte, origem, telefone, quem atende e
// o último resumo de handoff da IA.
/* global axios */
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useMapGetter } from 'dashboard/composables/store';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import SynapseStatusBadge from 'next/synapseos/SynapseStatusBadge.vue';
import SynapseSkeleton from 'next/synapseos/SynapseSkeleton.vue';
import SynapseEmptyState from 'next/synapseos/SynapseEmptyState.vue';
import { agentClasses } from 'dashboard/helper/synapseos/agentIdentity';
import { formatPhone } from 'dashboard/helper/synapseos/phone';
import { useBotControl } from './useBotControl';
import { useConversationLead } from './useConversationLead';

const props = defineProps({
  conversationId: { type: [Number, String], required: true },
  contact: { type: Object, default: () => ({}) },
});

const EMPTY = '—';

const HORIZON_KEYS = {
  imediato: 'IMMEDIATE',
  '1-3m': 'ONE_TO_THREE_MONTHS',
  '3-6m': 'THREE_TO_SIX_MONTHS',
  '6-12m': 'SIX_TO_TWELVE_MONTHS',
  '+12m': 'OVER_TWELVE_MONTHS',
  sem_prazo: 'NO_DEADLINE',
};

const SOURCE_KEYS = {
  disparo_template: 'DISPARO',
  log_outgoing: 'DISPARO',
  n8n: 'AUTOMATION',
  n8n_handler_dualwrite: 'AUTOMATION',
  slack_approval: 'ALERT_APPROVED',
  bulk_generator: 'IMPORT',
  import: 'IMPORT',
  manual: 'MANUAL',
};

const { t, locale } = useI18n();
const accountId = useMapGetter('getCurrentAccountId');
const currentChat = useMapGetter('getSelectedChat');
const { bot } = useBotControl();
const { lead, stage, stageBadge, isLoading, refresh } = useConversationLead(
  () => props.conversationId
);

const apiBase = computed(() => `/api/v1/accounts/${accountId.value}/synapseos`);

const stages = ref([]);
const lossReasons = ref([]);
const pendingStage = ref(null);
const lossReason = ref('');
const isMoving = ref(false);
const confirmDialogRef = ref(null);

const humanize = value => {
  const text = String(value).replace(/[_-]+/g, ' ').trim();
  return text.charAt(0).toUpperCase() + text.slice(1);
};

// Campos legados ficam no metadata (upsert do n8n); os do ADR-003 em colunas.
const interest = computed(
  () => lead.value.modelo_interesse || lead.value.metadata?.modelo_interesse
);

const horizon = computed(() => {
  const value =
    lead.value.horizonte_compra || lead.value.metadata?.horizonte_compra;
  if (!value) return '';
  return HORIZON_KEYS[value]
    ? t(`SYNAPSEOS.CONVERSATION.LEAD_CARD.HORIZONS.${HORIZON_KEYS[value]}`)
    : humanize(value);
});

const source = computed(() => {
  const value = lead.value.source;
  if (!value) return '';
  return SOURCE_KEYS[value]
    ? t(`SYNAPSEOS.CONVERSATION.LEAD_CARD.SOURCES.${SOURCE_KEYS[value]}`)
    : humanize(value);
});

const phone = computed(() => formatPhone(props.contact?.phone_number));

const assignee = computed(() => currentChat.value?.meta?.assignee);
const assigneeName = computed(
  () => assignee.value?.available_name || assignee.value?.name
);
const botDotClass = computed(() => agentClasses({ name: bot.value?.name }).bg);

const handoff = computed(() => lead.value?.handoff);
const handoffMeta = computed(() => {
  const date = new Intl.DateTimeFormat(locale.value.replace('_', '-'), {
    dateStyle: 'short',
    timeStyle: 'short',
  }).format(new Date(handoff.value.created_at));
  return [handoff.value.motivo, date].filter(Boolean).join(' · ');
});

const isConfirmStage = target => ['won', 'lost'].includes(target.stage_type);
const isLostPending = computed(() => pendingStage.value?.stage_type === 'lost');

const confirmDescription = computed(() =>
  isLostPending.value
    ? t('SYNAPSEOS.CONVERSATION.LEAD_CARD.MOVE.CONFIRM_LOST')
    : t('SYNAPSEOS.CONVERSATION.LEAD_CARD.MOVE.CONFIRM_WON')
);

const fetchStages = async () => {
  const { data } = await axios.get(`${apiBase.value}/pipeline_stages`);
  stages.value = data;
};

const fetchLossReasons = async () => {
  if (lossReasons.value.length) return;
  const { data } = await axios.get(
    `${apiBase.value}/pipeline_stages/loss_reasons`
  );
  lossReasons.value = data.loss_reasons || [];
};

// Mesmo PATCH do board da pipeline; o motivo vai junto ao mover para 'lost'.
const moveStage = async () => {
  const target = pendingStage.value;
  const payload = { pipeline_stage_id: target.id };
  if (target.stage_type === 'lost' && lossReason.value) {
    payload.motivo = lossReason.value;
  }
  isMoving.value = true;
  try {
    await axios.patch(`${apiBase.value}/leads/${lead.value.id}`, {
      lead: payload,
    });
    await refresh();
    useAlert(
      t('SYNAPSEOS.CONVERSATION.LEAD_CARD.MOVE.SUCCESS', { stage: target.name })
    );
  } catch {
    useAlert(t('SYNAPSEOS.CONVERSATION.LEAD_CARD.MOVE.ERROR'));
  } finally {
    isMoving.value = false;
    pendingStage.value = null;
  }
};

const onSelectStage = async id => {
  const target = stages.value.find(s => s.id === id);
  pendingStage.value = target;
  if (!isConfirmStage(target)) {
    moveStage();
    return;
  }
  lossReason.value = '';
  confirmDialogRef.value.open();
  if (target.stage_type === 'lost') await fetchLossReasons();
};

const onConfirmMove = async () => {
  await moveStage();
  confirmDialogRef.value.close();
};

// O select mostra a etapa pendente enquanto o diálogo está aberto; ao cancelar
// volta para a etapa atual.
const selectedStageId = computed({
  get: () => pendingStage.value?.id ?? stage.value?.id ?? '',
  set: onSelectStage,
});

const isConfirmDisabled = computed(
  () => isLostPending.value && lossReasons.value.length > 0 && !lossReason.value
);

// Etapas só são buscadas quando a conversa tem lead.
watch(
  () => lead.value?.id,
  id => id && !stages.value.length && fetchStages(),
  { immediate: true }
);
</script>

<template>
  <div class="flex flex-col gap-3 p-3">
    <div v-if="isLoading" class="flex flex-col gap-2">
      <SynapseSkeleton class="h-6 w-32" />
      <SynapseSkeleton class="h-9 w-full" />
      <SynapseSkeleton class="h-4 w-full" />
      <SynapseSkeleton class="h-4 w-3/4" />
    </div>

    <SynapseEmptyState
      v-else-if="!lead"
      size="sm"
      icon="i-lucide-user-search"
      :title="$t('SYNAPSEOS.CONVERSATION.LEAD_CARD.EMPTY')"
    />

    <template v-else>
      <div class="flex items-center justify-between gap-2">
        <SynapseStatusBadge v-if="stageBadge" v-bind="stageBadge" />
        <span v-else class="text-xs text-s-muted">
          {{ $t('SYNAPSEOS.CONVERSATION.LEAD_CARD.NO_STAGE') }}
        </span>
        <router-link
          :to="{ name: 'synapseos_pipeline', params: { accountId } }"
          class="inline-flex items-center gap-1 text-xs font-medium text-s-brand-text hover:underline"
        >
          {{ $t('SYNAPSEOS.CONVERSATION.LEAD_CARD.VIEW_PIPELINE') }}
          <span class="i-lucide-arrow-up-right size-3.5" aria-hidden="true" />
        </router-link>
      </div>

      <label class="flex flex-col gap-1">
        <span class="text-xs text-s-muted">
          {{ $t('SYNAPSEOS.CONVERSATION.LEAD_CARD.FIELDS.STAGE') }}
        </span>
        <select
          v-model="selectedStageId"
          class="!mb-0 !h-9 text-sm"
          :disabled="isMoving || !stages.length"
        >
          <option value="" disabled>
            {{ $t('SYNAPSEOS.CONVERSATION.LEAD_CARD.NO_STAGE') }}
          </option>
          <option v-for="item in stages" :key="item.id" :value="item.id">
            {{ item.name }}
          </option>
        </select>
      </label>

      <dl class="flex flex-col gap-2 m-0">
        <div class="flex items-baseline justify-between gap-3">
          <dt class="text-xs text-s-muted shrink-0">
            {{ $t('SYNAPSEOS.CONVERSATION.LEAD_CARD.FIELDS.INTEREST') }}
          </dt>
          <dd
            class="m-0 text-sm font-medium text-s-primary text-right truncate"
          >
            {{ interest || EMPTY }}
          </dd>
        </div>
        <div class="flex items-baseline justify-between gap-3">
          <dt class="text-xs text-s-muted shrink-0">
            {{ $t('SYNAPSEOS.CONVERSATION.LEAD_CARD.FIELDS.HORIZON') }}
          </dt>
          <dd
            class="m-0 text-sm font-medium text-s-primary text-right truncate"
          >
            {{ horizon || EMPTY }}
          </dd>
        </div>
        <div class="flex items-baseline justify-between gap-3">
          <dt class="text-xs text-s-muted shrink-0">
            {{ $t('SYNAPSEOS.CONVERSATION.LEAD_CARD.FIELDS.SOURCE') }}
          </dt>
          <dd
            class="m-0 text-sm font-medium text-s-primary text-right truncate"
          >
            {{ source || EMPTY }}
          </dd>
        </div>
        <div class="flex items-baseline justify-between gap-3">
          <dt class="text-xs text-s-muted shrink-0">
            {{ $t('SYNAPSEOS.CONVERSATION.LEAD_CARD.FIELDS.PHONE') }}
          </dt>
          <dd class="m-0 font-mono text-sm text-s-primary text-right truncate">
            {{ phone || EMPTY }}
          </dd>
        </div>
        <div class="flex items-baseline justify-between gap-3">
          <dt class="text-xs text-s-muted shrink-0">
            {{ $t('SYNAPSEOS.CONVERSATION.LEAD_CARD.FIELDS.HANDLING') }}
          </dt>
          <dd
            class="flex items-center justify-end min-w-0 gap-1.5 m-0 text-sm font-medium text-s-primary"
          >
            <template v-if="bot">
              <span class="size-2 rounded-full shrink-0" :class="botDotClass" />
              <span class="truncate">{{ bot.name }}</span>
            </template>
            <span
              v-if="bot && assigneeName"
              class="i-lucide-arrow-right size-3.5 shrink-0 text-s-muted"
              aria-hidden="true"
            />
            <span v-if="assigneeName" class="truncate">
              {{ assigneeName }}
            </span>
            <template v-if="!bot && !assigneeName">{{ EMPTY }}</template>
          </dd>
        </div>
      </dl>

      <div
        v-if="handoff?.summary"
        class="flex flex-col gap-1 p-2.5 rounded-lg bg-s-subtle border border-s-border"
      >
        <span class="text-xs font-medium text-s-secondary">
          {{ $t('SYNAPSEOS.CONVERSATION.LEAD_CARD.FIELDS.HANDOFF') }}
        </span>
        <p
          class="m-0 text-sm leading-relaxed text-s-primary whitespace-pre-line"
        >
          {{ handoff.summary }}
        </p>
        <span class="text-xs text-s-muted">{{ handoffMeta }}</span>
      </div>
    </template>

    <Dialog
      ref="confirmDialogRef"
      type="alert"
      :title="
        $t('SYNAPSEOS.CONVERSATION.LEAD_CARD.MOVE.CONFIRM_TITLE', {
          stage: pendingStage?.name,
        })
      "
      :description="confirmDescription"
      :confirm-button-label="
        $t('SYNAPSEOS.CONVERSATION.LEAD_CARD.MOVE.CONFIRM')
      "
      :is-loading="isMoving"
      :disable-confirm-button="isConfirmDisabled"
      @confirm="onConfirmMove"
      @close="pendingStage = null"
    >
      <label
        v-if="isLostPending && lossReasons.length"
        class="flex flex-col gap-1"
      >
        <span class="text-sm text-s-secondary">
          {{ $t('SYNAPSEOS.CONVERSATION.LEAD_CARD.MOVE.LOSS_REASON') }}
        </span>
        <select v-model="lossReason" class="!mb-0 text-sm">
          <option value="" disabled>
            {{
              $t(
                'SYNAPSEOS.CONVERSATION.LEAD_CARD.MOVE.LOSS_REASON_PLACEHOLDER'
              )
            }}
          </option>
          <option v-for="reason in lossReasons" :key="reason" :value="reason">
            {{ reason }}
          </option>
        </select>
      </label>
    </Dialog>
  </div>
</template>
