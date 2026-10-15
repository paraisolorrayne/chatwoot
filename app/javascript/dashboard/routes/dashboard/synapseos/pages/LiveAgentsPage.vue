<script setup>
import { ref, computed, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute } from 'vue-router';
import { useDocumentVisibility, useIntervalFn } from '@vueuse/core';
/* global axios */
import DataTable from 'primevue/datatable';
import Column from 'primevue/column';
import SynapseCard from 'next/synapseos/SynapseCard.vue';
import SynapseKpiCard from 'next/synapseos/SynapseKpiCard.vue';
import SynapseStatusPill from 'next/synapseos/SynapseStatusPill.vue';
import SynapseBadge from 'next/synapseos/SynapseBadge.vue';
import SynapseButton from 'next/synapseos/SynapseButton.vue';
import SynapsePageHeader from 'next/synapseos/SynapsePageHeader.vue';
import SynapseEmptyState from 'next/synapseos/SynapseEmptyState.vue';
import AgentConversationsPanel from '../components/AgentConversationsPanel.vue';

const POLL_MS = 15000;

const { t } = useI18n();
const route = useRoute();
const agents = ref([]);
const loading = ref(true);
const refreshing = ref(false);
const updatedAt = ref(null);
const fetchError = ref(null);
const searchQuery = ref('');
const selectedAgent = ref(null);
const conversationsPanel = ref(null);

const availabilityTone = availability => {
  const map = { online: 'success', busy: 'warning', offline: 'neutral' };
  return map[availability] || 'neutral';
};

const formatSeconds = seconds => {
  if (seconds === null || seconds === undefined) return '—';
  if (seconds < 60) return `${seconds}s`;
  const minutes = Math.floor(seconds / 60);
  const remainder = seconds % 60;
  return remainder ? `${minutes}m ${remainder}s` : `${minutes}m`;
};

const firstResponseClass = seconds => {
  if (seconds === null || seconds === undefined) return 'text-s-muted';
  return seconds > 300 ? 'text-s-warning-text' : 'text-s-muted';
};

const fetchAgents = async () => {
  refreshing.value = true;
  try {
    const { data } = await axios.get(
      `/api/v1/accounts/${route.params.accountId}/synapseos/live_agents`
    );
    agents.value = data;
    updatedAt.value = Date.now();
    fetchError.value = null;
  } catch (err) {
    // Endpoint falhou (401/403/404/500/network): mostra o banner com retry.
    fetchError.value = err?.response?.data?.message || err.message;
  } finally {
    loading.value = false;
    refreshing.value = false;
  }
};

// CUSTOMIZAÇÃO_SYNAPSEOS: polling único da tela (lista + painel do agente
// selecionado), pausado com a aba oculta.
const refreshAll = () => {
  fetchAgents();
  conversationsPanel.value?.fetchConversations();
};

const { pause, resume } = useIntervalFn(refreshAll, POLL_MS);
const visibility = useDocumentVisibility();
watch(visibility, state => {
  if (state === 'hidden') {
    pause();
    return;
  }
  refreshAll();
  resume();
});

fetchAgents();

const filteredAgents = computed(() => {
  if (!searchQuery.value.trim()) return agents.value;
  const q = searchQuery.value.toLowerCase();
  return agents.value.filter(
    a => a.name?.toLowerCase().includes(q) || a.email?.toLowerCase().includes(q)
  );
});

const summary = computed(() => {
  const total = agents.value.length;
  const online = agents.value.filter(a => a.availability === 'online').length;
  const busy = agents.value.filter(a => a.availability === 'busy').length;
  const offline = agents.value.filter(a => a.availability === 'offline').length;
  const openConversations = agents.value.reduce(
    (sum, a) => sum + (a.open_conversations || 0),
    0
  );
  const handledToday = agents.value.reduce(
    (sum, a) => sum + (a.conversations_today || 0),
    0
  );
  return { total, online, busy, offline, openConversations, handledToday };
});

const summaryCards = computed(() => [
  {
    key: 'total',
    label: t('SYNAPSEOS.LIVE_AGENTS.SUMMARY.TOTAL'),
    value: summary.value.total,
    icon: 'i-lucide-users',
    tone: 'neutral',
  },
  {
    key: 'online',
    label: t('SYNAPSEOS.LIVE_AGENTS.SUMMARY.ONLINE'),
    value: summary.value.online,
    icon: 'i-lucide-wifi',
    tone: 'success',
  },
  {
    key: 'busy',
    label: t('SYNAPSEOS.LIVE_AGENTS.SUMMARY.BUSY'),
    value: summary.value.busy,
    icon: 'i-lucide-clock',
    tone: 'warning',
  },
  {
    key: 'offline',
    label: t('SYNAPSEOS.LIVE_AGENTS.SUMMARY.OFFLINE'),
    value: summary.value.offline,
    icon: 'i-lucide-wifi-off',
    tone: 'neutral',
  },
  {
    key: 'open',
    label: t('SYNAPSEOS.LIVE_AGENTS.SUMMARY.OPEN'),
    value: summary.value.openConversations,
    icon: 'i-lucide-message-circle',
    tone: 'brand',
  },
  {
    key: 'handled',
    label: t('SYNAPSEOS.LIVE_AGENTS.SUMMARY.HANDLED_TODAY'),
    value: summary.value.handledToday,
    icon: 'i-lucide-check-circle',
    tone: 'success',
  },
]);

const handleRowClick = event => {
  const agent = event?.data;
  if (!agent) return;
  if (selectedAgent.value?.id === agent.id) {
    selectedAgent.value = null;
  } else {
    selectedAgent.value = agent;
  }
};

const rowClass = data =>
  selectedAgent.value?.id === data?.id ? 'bg-s-hover' : null;
</script>

<template>
  <div
    class="bg-s-bg p-4 sm:p-6 md:p-8 space-y-4 md:space-y-6 h-full w-full flex-1 min-w-0 overflow-auto"
  >
    <SynapsePageHeader
      :title="t('SYNAPSEOS.LIVE_AGENTS.TITLE')"
      :description="t('SYNAPSEOS.LIVE_AGENTS.SUBTITLE')"
      :updated-at="fetchError ? null : updatedAt"
      :refreshing="refreshing"
    />

    <div
      v-if="fetchError"
      role="alert"
      class="flex flex-wrap items-center gap-3 px-4 py-3 rounded-lg border border-s-error/30 bg-s-error-soft text-s-error-text text-sm"
    >
      <span
        class="i-lucide-triangle-alert size-4 shrink-0"
        aria-hidden="true"
      />
      <div class="flex-1 min-w-0">
        <p class="font-semibold">
          {{ t('SYNAPSEOS.LIVE_AGENTS.ERROR.TITLE') }}
        </p>
        <p class="text-xs">{{ fetchError }}</p>
      </div>
      <SynapseButton
        variant="outline"
        size="sm"
        icon="i-lucide-refresh-cw"
        :loading="refreshing"
        @click="fetchAgents"
      >
        {{ t('SYNAPSEOS.LIVE_AGENTS.ERROR.RETRY') }}
      </SynapseButton>
    </div>

    <section
      class="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-6 gap-3 sm:gap-4"
    >
      <SynapseKpiCard
        v-for="card in summaryCards"
        :key="card.key"
        :label="card.label"
        :value="String(card.value)"
        :icon="card.icon"
        :tone="card.tone"
        :loading="loading"
      />
    </section>

    <div
      class="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-3 sm:gap-4"
    >
      <!-- Input próprio (reset-base): o estilo global de input do Chatwoot
           sobrescrevia o recuo do ícone no SynapseInput. -->
      <div class="relative w-full sm:w-72">
        <span
          class="i-lucide-search absolute left-3 top-1/2 -translate-y-1/2 size-4 text-s-muted pointer-events-none"
          aria-hidden="true"
        />
        <input
          v-model="searchQuery"
          type="search"
          class="reset-base w-full h-10 pl-9 pr-3 rounded-lg bg-s-surface border border-s-border text-sm text-s-primary placeholder:text-s-muted hover:border-s-border-strong focus:outline-none focus:ring-2 focus:ring-s-focus focus:border-s-brand"
          :placeholder="t('SYNAPSEOS.LIVE_AGENTS.SEARCH_PLACEHOLDER')"
          :aria-label="t('SYNAPSEOS.LIVE_AGENTS.SEARCH_LABEL')"
        />
      </div>
      <span class="text-xs text-s-muted">
        {{ t('SYNAPSEOS.LIVE_AGENTS.REFRESH_HINT') }}
      </span>
    </div>

    <div class="grid grid-cols-1 lg:grid-cols-[3fr_2fr] gap-4 items-start">
      <SynapseCard padding="none" class="min-w-0 overflow-x-auto">
        <DataTable
          :value="filteredAgents"
          :loading="loading"
          data-key="id"
          removable-sort
          row-hover
          :row-class="rowClass"
          :pt="{
            table: { class: 'min-w-full' },
            bodyRow: { class: 'cursor-pointer transition-colors' },
            headerCell: {
              class:
                'text-xs font-semibold uppercase tracking-wide px-4 py-3 whitespace-nowrap',
            },
            bodyCell: { class: 'px-4 py-3 text-sm align-middle' },
            emptyMessage: { class: 'text-center py-8 text-sm text-s-muted' },
          }"
          class="w-full"
          @row-click="handleRowClick"
        >
          <template #empty>
            <SynapseEmptyState
              icon="i-lucide-users"
              :title="t('SYNAPSEOS.LIVE_AGENTS.EMPTY_TITLE')"
              :description="t('SYNAPSEOS.LIVE_AGENTS.EMPTY_DESCRIPTION')"
              size="md"
            />
          </template>
          <Column
            field="name"
            :header="t('SYNAPSEOS.LIVE_AGENTS.COL_NAME')"
            sortable
          >
            <template #body="{ data }">
              <div class="flex items-center gap-3 min-w-0 max-w-[280px]">
                <img
                  v-if="data.thumbnail"
                  :src="data.thumbnail"
                  :alt="data.name"
                  class="rounded-full size-8"
                />
                <div
                  v-else
                  class="rounded-full size-8 bg-s-subtle flex items-center justify-center text-xs text-s-secondary font-medium"
                >
                  {{ data.name?.[0]?.toUpperCase() || '?' }}
                </div>
                <div class="flex flex-col min-w-0">
                  <span class="text-sm font-semibold text-s-primary truncate">
                    {{ data.name }}
                  </span>
                  <span class="text-xs text-s-secondary truncate">
                    {{ data.email }}
                  </span>
                </div>
              </div>
            </template>
          </Column>

          <Column
            field="availability"
            :header="t('SYNAPSEOS.LIVE_AGENTS.COL_STATUS')"
            sortable
          >
            <template #body="{ data }">
              <SynapseStatusPill :tone="availabilityTone(data.availability)">
                {{
                  t(
                    `SYNAPSEOS.LIVE_AGENTS.STATUS.${data.availability.toUpperCase()}`
                  )
                }}
              </SynapseStatusPill>
            </template>
          </Column>

          <Column
            field="open_conversations"
            :header="t('SYNAPSEOS.LIVE_AGENTS.COL_OPEN')"
            sortable
          />
          <Column
            field="conversations_today"
            :header="t('SYNAPSEOS.LIVE_AGENTS.COL_TODAY')"
            sortable
          />

          <Column
            field="avg_first_response_seconds"
            :header="t('SYNAPSEOS.LIVE_AGENTS.COL_FIRST_RESPONSE')"
            sortable
          >
            <template #body="{ data }">
              <span
                class="text-sm"
                :class="firstResponseClass(data.avg_first_response_seconds)"
              >
                {{ formatSeconds(data.avg_first_response_seconds) }}
              </span>
            </template>
          </Column>

          <Column
            field="role"
            :header="t('SYNAPSEOS.LIVE_AGENTS.COL_ROLE')"
            sortable
          >
            <template #body="{ data }">
              <SynapseBadge
                :tone="data.role === 'administrator' ? 'brand' : 'neutral'"
              >
                {{
                  data.role === 'administrator'
                    ? t('SYNAPSEOS.LIVE_AGENTS.ROLE.ADMINISTRATOR')
                    : t('SYNAPSEOS.LIVE_AGENTS.ROLE.AGENT')
                }}
              </SynapseBadge>
            </template>
          </Column>
        </DataTable>
      </SynapseCard>

      <div v-if="selectedAgent" class="min-w-0">
        <AgentConversationsPanel
          ref="conversationsPanel"
          :agent="selectedAgent"
          @close="selectedAgent = null"
        />
      </div>
      <SynapseCard
        v-else
        padding="none"
        class="hidden lg:flex items-center justify-center min-h-[300px] min-w-0"
      >
        <SynapseEmptyState
          icon="i-lucide-mouse-pointer-click"
          :title="t('SYNAPSEOS.LIVE_AGENTS.PANEL.HINT')"
          size="sm"
        />
      </SynapseCard>
    </div>
  </div>
</template>
