<script setup>
// CUSTOMIZAÇÃO_SYNAPSEOS — últimos alertas de venda aprovados + popup de
// detalhes. `conversation_id` dos CrmEvents é o DISPLAY id da conversa.
import { ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute } from 'vue-router';
import SynapseBadge from 'next/synapseos/SynapseBadge.vue';
import SynapseSkeleton from 'next/synapseos/SynapseSkeleton.vue';
import SynapseEmptyState from 'next/synapseos/SynapseEmptyState.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import { useDashboardFormat } from './useDashboardFormat';

const props = defineProps({
  events: { type: Array, default: () => [] },
  loading: { type: Boolean, default: false },
  // Momento da última atualização: base do tempo relativo ("há 5 min").
  now: { type: Number, default: null },
});

const { t } = useI18n();
const route = useRoute();
const { formatRelative, formatPersonName } = useDashboardFormat();

const alerts = computed(() =>
  props.events.map(event => ({
    ...event,
    name: formatPersonName(event.contact_name) || '—',
    model:
      event.modelo_interesse ||
      t('SYNAPSEOS.DASHBOARD.ALERT_DETAILS.MODEL_UNDEFINED'),
    relativeTime: formatRelative(event.created_at, props.now),
  }))
);

const dialog = ref(null);
const selected = ref(null);
const openAlert = alert => {
  selected.value = alert;
  dialog.value.open();
};

const conversationRoute = computed(() => ({
  name: 'inbox_conversation',
  params: {
    accountId: route.params.accountId,
    conversation_id: selected.value.conversation_id,
  },
}));
</script>

<template>
  <section
    class="bg-s-surface border border-s-border rounded-lg flex flex-col min-w-0"
  >
    <header
      class="px-4 py-3 border-b border-s-border flex items-center justify-between gap-3"
    >
      <h2 class="text-sm font-semibold text-s-primary">
        {{ t('SYNAPSEOS.DASHBOARD.RECENT_EVENTS.TITLE') }}
      </h2>
      <span
        v-if="alerts.length"
        class="text-xs font-mono text-s-muted tabular-nums"
      >
        {{ alerts.length }}
      </span>
    </header>

    <div v-if="loading" class="p-4 flex flex-col gap-4">
      <SynapseSkeleton v-for="n in 4" :key="n" class="h-10 w-full" />
    </div>

    <ul
      v-else-if="alerts.length"
      class="flex flex-col divide-y divide-s-border overflow-auto max-h-80"
    >
      <li v-for="alert in alerts" :key="alert.id">
        <button
          type="button"
          class="w-full flex items-start gap-3 px-4 py-3 text-left hover:bg-s-hover transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-inset focus-visible:ring-s-focus"
          @click="openAlert(alert)"
        >
          <span
            class="i-lucide-user-check size-4 mt-0.5 shrink-0 text-s-brand-text"
            aria-hidden="true"
          />
          <span class="flex flex-col min-w-0 flex-1 gap-1">
            <span class="text-sm font-medium text-s-primary truncate">
              {{ alert.name }}
            </span>
            <span class="flex items-center gap-2 flex-wrap">
              <SynapseBadge tone="brand">{{ alert.model }}</SynapseBadge>
              <span class="text-xs text-s-muted tabular-nums">
                {{ alert.relativeTime }}
              </span>
            </span>
          </span>
        </button>
      </li>
    </ul>

    <SynapseEmptyState
      v-else
      icon="i-lucide-bell"
      :title="t('SYNAPSEOS.DASHBOARD.EMPTY_EVENTS_TITLE')"
      :description="t('SYNAPSEOS.DASHBOARD.EMPTY_EVENTS_DESCRIPTION')"
      size="sm"
      class="px-4"
    />

    <Dialog
      ref="dialog"
      :title="t('SYNAPSEOS.DASHBOARD.ALERT_DETAILS.TITLE')"
      :show-confirm-button="false"
      :cancel-button-label="t('SYNAPSEOS.DASHBOARD.ALERT_DETAILS.CLOSE')"
    >
      <div v-if="selected" class="flex flex-col gap-3 text-sm">
        <dl class="flex flex-col gap-3">
          <div class="flex flex-col gap-0.5">
            <dt
              class="text-xs font-medium uppercase tracking-wider text-s-muted"
            >
              {{ t('SYNAPSEOS.DASHBOARD.ALERT_DETAILS.CLIENT') }}
            </dt>
            <dd class="text-s-primary font-medium">{{ selected.name }}</dd>
          </div>
          <div class="flex flex-col gap-0.5">
            <dt
              class="text-xs font-medium uppercase tracking-wider text-s-muted"
            >
              {{ t('SYNAPSEOS.DASHBOARD.ALERT_DETAILS.INTEREST') }}
            </dt>
            <dd class="text-s-primary">{{ selected.model }}</dd>
          </div>
          <div v-if="selected.tipo" class="flex flex-col gap-0.5">
            <dt
              class="text-xs font-medium uppercase tracking-wider text-s-muted"
            >
              {{ t('SYNAPSEOS.DASHBOARD.ALERT_DETAILS.REASON') }}
            </dt>
            <dd class="text-s-primary">{{ selected.tipo }}</dd>
          </div>
          <div
            v-if="selected.metadata?.observacoes"
            class="flex flex-col gap-0.5"
          >
            <dt
              class="text-xs font-medium uppercase tracking-wider text-s-muted"
            >
              {{ t('SYNAPSEOS.DASHBOARD.ALERT_DETAILS.NOTES') }}
            </dt>
            <dd class="text-s-secondary whitespace-pre-line">
              {{ selected.metadata.observacoes }}
            </dd>
          </div>
        </dl>
        <router-link
          v-if="selected.conversation_id"
          :to="conversationRoute"
          class="inline-flex items-center gap-1 text-s-brand-text hover:underline text-xs font-semibold mt-1"
        >
          {{ t('SYNAPSEOS.DASHBOARD.ALERT_DETAILS.OPEN_CONVERSATION') }}
          <span class="i-lucide-arrow-right size-3.5" aria-hidden="true" />
        </router-link>
      </div>
    </Dialog>
  </section>
</template>
