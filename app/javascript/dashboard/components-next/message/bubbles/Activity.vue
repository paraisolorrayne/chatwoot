<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import BaseBubble from './Base.vue';
import { useMessageContext } from '../provider.js';
import { formatMessageTime } from '../messageTime';

const { content, createdAt, contentAttributes } = useMessageContext();
const { locale } = useI18n();

const readableTime = computed(() =>
  formatMessageTime(createdAt.value, locale.value)
);

// CUSTOMIZAÇÃO_SYNAPSEOS — o handoff de venda chega como activity do
// Synapseos::CrmEvent e ganha destaque de evento; as demais seguem a pill
// neutra. Activities antigas (sem o marcador synapseos_event) caem no texto.
const SALES_EVENTS = ['sales_alert_dispatched', 'sales_alert_approved'];
const isSalesEvent = computed(() => {
  const { synapseosEvent, synapseosState } = contentAttributes.value || {};
  if (!synapseosEvent) return /alerta de venda/i.test(content.value);
  return (
    SALES_EVENTS.includes(synapseosEvent) ||
    (synapseosEvent === 'lead_state_changed' && synapseosState === 'quer')
  );
});
</script>

<template>
  <div
    v-if="isSalesEvent"
    v-tooltip.top="readableTime"
    class="flex items-center max-w-lg gap-2 px-3 py-2 text-sm font-medium border border-dashed rounded-xl border-s-accent/40 bg-s-bubble-ai text-s-primary"
    data-bubble-name="activity-event"
  >
    <span
      class="i-lucide-sparkles size-4 shrink-0 text-s-brand-text"
      aria-hidden="true"
    />
    <span v-dompurify-html="content" />
  </div>
  <BaseBubble
    v-else
    v-tooltip.top="readableTime"
    class="px-3 py-1 !rounded-xl flex min-w-0 items-center gap-2"
    data-bubble-name="activity"
  >
    <span v-dompurify-html="content" :title="content" />
  </BaseBubble>
</template>
