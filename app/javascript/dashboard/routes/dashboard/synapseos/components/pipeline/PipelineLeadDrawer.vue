<script setup>
// CUSTOMIZAÇÃO_SYNAPSEOS — drawer de detalhes do lead (Fykos). Fecha com Esc ou
// clique no fundo; o foco fica preso no painel enquanto aberto.
import { computed, nextTick, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute } from 'vue-router';
/* global axios */
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import SynapseButton from 'next/synapseos/SynapseButton.vue';
import SynapseStatusBadge from 'next/synapseos/SynapseStatusBadge.vue';
import { formatPhone } from 'dashboard/helper/synapseos/phone';
import { agentClasses } from 'dashboard/helper/synapseos/agentIdentity';
import {
  formatBRL,
  formatDateTime,
  horizonLabel,
  humanize,
  sourceLabel,
} from './pipelineHelpers';

const props = defineProps({
  lead: { type: Object, default: null },
  stage: { type: Object, default: null },
});

const emit = defineEmits(['close', 'openConversation']);

const { t, locale } = useI18n();
const route = useRoute();

const panel = ref(null);
const closeButton = ref(null);
const handoff = ref(null);
let returnFocusTo = null;

const yesNo = value => {
  if (value === null || value === undefined) return '';
  return t(value ? 'SYNAPSEOS.PIPELINE.YES' : 'SYNAPSEOS.PIPELINE.NO');
};

const details = computed(() => {
  const lead = props.lead;
  return [
    { key: 'MODEL', value: lead.modelo_interesse },
    { key: 'VALUE', value: formatBRL(lead.deal?.amount) },
    { key: 'HORIZON', value: horizonLabel(t, lead.horizonte_compra) },
    { key: 'TRADE_IN', value: yesNo(lead.tem_troca) },
    { key: 'PAYMENT', value: humanize(lead.forma_pagamento) },
    { key: 'URGENCY', value: humanize(lead.urgencia) },
    { key: 'SOURCE', value: sourceLabel(t, lead.source) },
    { key: 'REASON', value: humanize(lead.motivo) },
    {
      key: 'NEXT_ACTION',
      value: formatDateTime(locale.value, lead.next_action_at),
    },
    { key: 'UPDATED', value: formatDateTime(locale.value, lead.updated_at) },
    { key: 'CREATED', value: formatDateTime(locale.value, lead.created_at) },
  ].filter(detail => detail.value);
});

const handler = computed(() => props.lead?.handler);
const botDotClass = computed(
  () =>
    agentClasses({
      squadronRole: handler.value?.squadron_role,
      name: handler.value?.name,
    }).bg
);

// Resumo do handoff vem do endpoint by_conversation (uma chamada por abertura).
const fetchHandoff = async lead => {
  handoff.value = null;
  if (!lead.conversation_display_id) return;
  try {
    const { data } = await axios.get(
      `/api/v1/accounts/${route.params.accountId}/synapseos/leads/by_conversation/${lead.conversation_display_id}`
    );
    if (props.lead?.id === lead.id) handoff.value = data.handoff || null;
  } catch (e) {
    handoff.value = null;
  }
};

watch(
  () => props.lead?.id,
  async (id, previousId) => {
    if (!id) {
      returnFocusTo?.focus?.();
      returnFocusTo = null;
      return;
    }
    if (!previousId) returnFocusTo = document.activeElement;
    fetchHandoff(props.lead);
    await nextTick();
    closeButton.value?.focus();
  }
);

const FOCUSABLE =
  'a[href], button:not([disabled]), input, select, textarea, [tabindex]:not([tabindex="-1"])';

const trapFocus = event => {
  const items = [...panel.value.querySelectorAll(FOCUSABLE)];
  const first = items[0];
  const last = items[items.length - 1];
  if (event.shiftKey && document.activeElement === first) {
    event.preventDefault();
    last.focus();
  } else if (!event.shiftKey && document.activeElement === last) {
    event.preventDefault();
    first.focus();
  }
};
</script>

<template>
  <Teleport to="body">
    <div v-if="lead" class="fixed inset-0 z-50 flex justify-end">
      <div
        class="absolute inset-0 bg-s-primary/20 motion-safe:animate-s-fade-in"
        aria-hidden="true"
        @click="emit('close')"
      />
      <aside
        ref="panel"
        role="dialog"
        aria-modal="true"
        aria-labelledby="pipeline-lead-drawer-title"
        class="relative flex flex-col w-full max-w-md h-full bg-s-surface border-s border-s-border shadow-s-lg motion-safe:animate-s-slide-in-right"
        @keydown.esc="emit('close')"
        @keydown.tab="trapFocus"
      >
        <header
          class="flex items-start gap-3 px-6 pt-5 pb-4 border-b border-s-border"
        >
          <div class="flex flex-col gap-1 flex-1 min-w-0">
            <h2
              id="pipeline-lead-drawer-title"
              class="font-synapse-display text-lg font-semibold text-s-primary break-words"
            >
              {{ lead.contact?.name }}
            </h2>
            <div
              v-if="lead.contact?.phone_number"
              class="font-mono text-xs text-s-muted"
            >
              {{ formatPhone(lead.contact.phone_number) }}
            </div>
            <div class="flex flex-wrap items-center gap-1.5 mt-1">
              <SynapseStatusBadge
                v-if="stage"
                :status="stage.slug || stage.name"
                :label="stage.name"
                :stage-type="stage.stage_type"
              />
              <SynapseStatusBadge v-if="lead.estado" :status="lead.estado" />
            </div>
          </div>
          <button
            ref="closeButton"
            type="button"
            class="shrink-0 p-1.5 rounded-md text-s-secondary hover:text-s-primary hover:bg-s-hover focus:outline-none focus-visible:ring-2 focus-visible:ring-focus"
            :aria-label="t('SYNAPSEOS.PIPELINE.CLOSE')"
            @click="emit('close')"
          >
            <span class="i-lucide-x block size-4" />
          </button>
        </header>

        <div
          class="flex flex-col gap-5 flex-1 min-h-0 overflow-y-auto px-6 py-5"
        >
          <div v-if="handler" class="flex items-center gap-2 text-sm">
            <span class="text-s-muted">
              {{ t('SYNAPSEOS.PIPELINE.DRAWER.HANDLER') }}
            </span>
            <span
              v-if="handler.kind === 'bot'"
              class="size-2 rounded-full shrink-0"
              :class="botDotClass"
            />
            <Avatar
              v-else
              :name="handler.name"
              :src="handler.avatar_url"
              :size="20"
              rounded-full
            />
            <span class="font-medium text-s-primary">{{ handler.name }}</span>
          </div>

          <dl class="grid grid-cols-[auto_1fr] gap-x-4 gap-y-2 text-sm">
            <template v-for="detail in details" :key="detail.key">
              <dt class="text-s-muted">
                {{ t(`SYNAPSEOS.PIPELINE.DRAWER.FIELDS.${detail.key}`) }}
              </dt>
              <dd class="text-s-primary break-words">{{ detail.value }}</dd>
            </template>
          </dl>

          <section v-if="handoff?.summary" class="flex flex-col gap-1.5">
            <h3
              class="text-xs font-semibold uppercase tracking-wide text-s-muted"
            >
              {{ t('SYNAPSEOS.PIPELINE.DRAWER.HANDOFF') }}
            </h3>
            <div
              class="text-sm text-s-secondary whitespace-pre-line break-words"
            >
              {{ handoff.summary }}
            </div>
          </section>

          <section v-if="lead.last_message" class="flex flex-col gap-1.5">
            <h3
              class="text-xs font-semibold uppercase tracking-wide text-s-muted"
            >
              {{ t('SYNAPSEOS.PIPELINE.DRAWER.LAST_MESSAGE') }}
            </h3>
            <div
              class="rounded-lg bg-s-subtle px-3 py-2 text-sm text-s-secondary break-words"
            >
              {{ lead.last_message.content }}
            </div>
            <div class="text-xs text-s-muted">
              {{ formatDateTime(locale, lead.last_message.created_at) }}
            </div>
          </section>
        </div>

        <footer class="px-6 py-4 border-t border-s-border">
          <SynapseButton
            variant="primary"
            icon="i-lucide-message-circle"
            block
            :disabled="!lead.conversation_display_id"
            @click="emit('openConversation')"
          >
            {{ t('SYNAPSEOS.PIPELINE.DRAWER.OPEN_CONVERSATION') }}
          </SynapseButton>
        </footer>
      </aside>
    </div>
  </Teleport>
</template>
