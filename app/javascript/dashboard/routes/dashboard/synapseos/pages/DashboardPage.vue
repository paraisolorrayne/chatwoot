<script setup>
// CUSTOMIZAÇÃO_SYNAPSEOS — dashboard executivo (gerentes não técnicos).
// Primeira carga mostra skeletons; o polling de 30 s atualiza em segundo plano
// sem esconder os dados e pausa com a aba oculta.
import { ref, computed, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute } from 'vue-router';
import { useDocumentVisibility, useIntervalFn } from '@vueuse/core';
/* global axios */
import SynapsePageHeader from 'next/synapseos/SynapsePageHeader.vue';
import SynapseKpiCard from 'next/synapseos/SynapseKpiCard.vue';
import SynapseSkeleton from 'next/synapseos/SynapseSkeleton.vue';
import SynapseBadge from 'next/synapseos/SynapseBadge.vue';
import SynapseButton from 'next/synapseos/SynapseButton.vue';
import SynapseEmptyState from 'next/synapseos/SynapseEmptyState.vue';
import DashboardFunnel from '../components/dashboard/DashboardFunnel.vue';
import DashboardActivityChart from '../components/dashboard/DashboardActivityChart.vue';
import DashboardRecentAlerts from '../components/dashboard/DashboardRecentAlerts.vue';
import { useDashboardFormat } from '../components/dashboard/useDashboardFormat';

const POLL_MS = 30000;
const PERIOD_OPTIONS = [7, 30, 90];

const { t } = useI18n();
const route = useRoute();
const {
  formatNumber,
  formatPercent,
  formatCurrency,
  formatPersonName,
  formatTime,
} = useDashboardFormat();

const period = ref(30);
const summary = ref(null);
// Série do gráfico separada: só muda quando os dados mudam, senão o Chart
// redesenharia (com animação) a cada polling.
const daily = ref([]);
const refreshing = ref(false);
const error = ref(null);
const updatedAt = ref(null);

const loading = computed(() => !summary.value);

const fetchSummary = async () => {
  const days = period.value;
  refreshing.value = true;
  try {
    const { data } = await axios.get(
      `/api/v1/accounts/${route.params.accountId}/synapseos/dashboard/summary`,
      { params: { days } }
    );
    // Resposta de um período que o usuário já trocou: descarta.
    if (days !== period.value) return;
    summary.value = data;
    if (JSON.stringify(data.daily) !== JSON.stringify(daily.value)) {
      daily.value = data.daily;
    }
    updatedAt.value = Date.now();
    error.value = null;
  } catch (err) {
    error.value = err;
  } finally {
    refreshing.value = false;
  }
};

const { pause, resume } = useIntervalFn(fetchSummary, POLL_MS);
const visibility = useDocumentVisibility();
watch(visibility, state => {
  if (state === 'hidden') {
    pause();
    return;
  }
  fetchSummary();
  resume();
});

watch(period, () => {
  summary.value = null;
  daily.value = [];
  fetchSummary();
});

fetchSummary();

// Delta % vs. período anterior; sem base (0) não há comparação possível.
const pctDelta = (current, previous) =>
  previous ? Math.round(((current - previous) / previous) * 1000) / 10 : null;
// Delta em pontos percentuais (taxas).
const ppDelta = (current, previous) =>
  previous === undefined ? null : Math.round((current - previous) * 10) / 10;

const kpis = computed(() => summary.value?.kpis || {});
const previousKpis = computed(() => summary.value?.previous_period.kpis || {});

const heroCards = computed(() => {
  const k = kpis.value;
  const p = previousKpis.value;
  return [
    // Negócios ganhos = coluna "Ganho" da pipeline (estado atual, sem delta:
    // não há histórico de entrada no stage para comparar períodos).
    {
      key: 'deals_won',
      label: t('SYNAPSEOS.DASHBOARD.KPI.DEALS_WON'),
      value: formatNumber(k.deals_won),
      hint: t('SYNAPSEOS.DASHBOARD.KPI.DEALS_WON_HINT'),
      icon: 'i-lucide-trophy',
      tone: 'success',
    },
    {
      key: 'revenue',
      label: t('SYNAPSEOS.DASHBOARD.KPI.REVENUE'),
      value: formatCurrency(k.revenue, { compact: k.revenue >= 1000000 }),
      title: formatCurrency(k.revenue),
      hint: t('SYNAPSEOS.DASHBOARD.KPI.REVENUE_HINT'),
      icon: 'i-lucide-banknote',
      tone: 'success',
      delta: pctDelta(k.revenue, p.revenue),
    },
    {
      key: 'conversion_rate',
      label: t('SYNAPSEOS.DASHBOARD.KPI.CONVERSION_RATE'),
      value: formatPercent(k.conversion_rate),
      hint: t('SYNAPSEOS.DASHBOARD.KPI.CONVERSION_RATE_HINT'),
      icon: 'i-lucide-filter',
      tone: 'brand',
      delta: ppDelta(k.conversion_rate, p.conversion_rate),
      deltaUnit: 'pp',
    },
    {
      key: 'shoots_period',
      label: t('SYNAPSEOS.DASHBOARD.KPI.SHOOTS_PERIOD'),
      value: formatNumber(k.shoots_period),
      hint: t('SYNAPSEOS.DASHBOARD.KPI.SHOOTS_PERIOD_HINT'),
      icon: 'i-lucide-send',
      tone: 'neutral',
      delta: pctDelta(k.shoots_period, p.shoots_period),
      sparkline: daily.value.map(d => d.messages_sent),
    },
  ];
});

const secondaryCards = computed(() => {
  const k = kpis.value;
  return [
    {
      key: 'deals_lost',
      label: t('SYNAPSEOS.DASHBOARD.KPI.DEALS_LOST'),
      value: formatNumber(k.deals_lost),
      hint: t('SYNAPSEOS.DASHBOARD.KPI.DEALS_LOST_HINT'),
      icon: 'i-lucide-circle-x',
      tone: 'neutral',
      positiveIs: 'down',
    },
    // Handoff é o objetivo da Elisa: tom de marca, nunca de alerta.
    {
      key: 'bot_takeovers',
      label: t('SYNAPSEOS.DASHBOARD.KPI.BOT_TAKEOVERS'),
      value: formatNumber(k.bot_takeovers),
      hint: t('SYNAPSEOS.DASHBOARD.KPI.BOT_TAKEOVERS_HINT'),
      icon: 'i-lucide-user-check',
      tone: 'brand',
      delta: pctDelta(k.bot_takeovers, previousKpis.value.bot_takeovers),
      sparkline: daily.value.map(d => d.bot_takeovers),
    },
  ];
});

// DISPAROS PROGRAMADOS HOJE (dry-run read-only do n8n via snapshot CrmEvent):
// disparos + follow-ups, só nome + últimos 4 dígitos.
const dryRun = computed(() => summary.value?.dry_run);
const dryRunItems = computed(() => {
  if (!dryRun.value) return [];
  const tag = (items, type, label, tone) =>
    items.map((item, index) => ({
      ...item,
      key: `${type}-${index}`,
      name: formatPersonName(item.nome),
      label,
      tone,
    }));
  return [
    ...tag(
      dryRun.value.disparos,
      'shoot',
      t('SYNAPSEOS.DASHBOARD.DRY_RUN.TYPE.SHOOT'),
      'brand'
    ),
    ...tag(
      dryRun.value.followups,
      'followup',
      t('SYNAPSEOS.DASHBOARD.DRY_RUN.TYPE.FOLLOW_UP'),
      'neutral'
    ),
  ];
});

// Bloco "Hoje" (dia corrente em BRT) — não reage ao filtro de período.
const todayStats = computed(() => [
  {
    key: 'shoots',
    label: t('SYNAPSEOS.DASHBOARD.TODAY.SHOOTS'),
    value: formatNumber(kpis.value.shoots_today),
  },
  {
    key: 'scheduled',
    label: t('SYNAPSEOS.DASHBOARD.TODAY.SCHEDULED'),
    value: dryRun.value ? formatNumber(dryRunItems.value.length) : '—',
  },
  {
    key: 'handoffs',
    label: t('SYNAPSEOS.DASHBOARD.TODAY.HANDOFFS'),
    value: formatNumber(kpis.value.bot_takeovers_today),
  },
]);

const errorDescription = computed(() =>
  summary.value
    ? t('SYNAPSEOS.DASHBOARD.ERROR.STALE', {
        time: formatTime(updatedAt.value),
      })
    : t('SYNAPSEOS.DASHBOARD.ERROR.DESCRIPTION')
);
</script>

<template>
  <div class="bg-s-bg h-full w-full flex-1 min-w-0 overflow-auto">
    <div class="p-4 md:p-6 flex flex-col gap-4 md:gap-6">
      <SynapsePageHeader
        :title="t('SYNAPSEOS.DASHBOARD.TITLE')"
        :description="t('SYNAPSEOS.DASHBOARD.SUBTITLE', { days: period })"
        :updated-at="error ? null : updatedAt"
        :refreshing="refreshing"
      >
        <template #actions>
          <div
            class="flex items-center gap-1 p-1 rounded-lg bg-s-subtle border border-s-border"
            role="group"
            :aria-label="t('SYNAPSEOS.DASHBOARD.PERIOD_LABEL')"
          >
            <button
              v-for="days in PERIOD_OPTIONS"
              :key="days"
              type="button"
              class="px-3 py-1 text-xs font-semibold rounded-md transition-colors tabular-nums focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-s-focus"
              :class="
                period === days
                  ? 'bg-s-surface text-s-primary shadow-s-sm'
                  : 'text-s-muted hover:text-s-secondary'
              "
              :aria-pressed="period === days"
              @click="period = days"
            >
              {{ t('SYNAPSEOS.DASHBOARD.PERIOD_DAYS', { days }) }}
            </button>
          </div>
        </template>
      </SynapsePageHeader>

      <div
        v-if="error"
        role="alert"
        class="flex flex-wrap items-center gap-3 rounded-lg border border-s-error/30 bg-s-error-soft text-s-error-text px-4 py-3 text-sm"
      >
        <span
          class="i-lucide-triangle-alert size-4 shrink-0"
          aria-hidden="true"
        />
        <div class="flex-1 min-w-0">
          <p class="font-semibold">
            {{ t('SYNAPSEOS.DASHBOARD.ERROR.TITLE') }}
          </p>
          <p class="text-xs">{{ errorDescription }}</p>
        </div>
        <SynapseButton
          variant="outline"
          size="sm"
          icon="i-lucide-refresh-cw"
          :loading="refreshing"
          @click="fetchSummary"
        >
          {{ t('SYNAPSEOS.DASHBOARD.ERROR.RETRY') }}
        </SynapseButton>
      </div>

      <template v-if="summary || !error">
        <section class="grid grid-cols-2 xl:grid-cols-4 gap-3 md:gap-4">
          <SynapseKpiCard
            v-for="card in heroCards"
            :key="card.key"
            :title="card.title"
            :label="card.label"
            :value="card.value"
            :icon="card.icon"
            :tone="card.tone"
            :hint="card.hint"
            :delta="card.delta ?? null"
            :delta-unit="card.deltaUnit"
            :sparkline="card.sparkline"
            :loading="loading"
            size="lg"
          />
        </section>

        <div class="grid grid-cols-2 xl:grid-cols-4 gap-3 md:gap-4">
          <SynapseKpiCard
            v-for="card in secondaryCards"
            :key="card.key"
            :label="card.label"
            :value="card.value"
            :icon="card.icon"
            :tone="card.tone"
            :hint="card.hint"
            :delta="card.delta ?? null"
            :positive-is="card.positiveIs"
            :sparkline="card.sparkline"
            :loading="loading"
          />

          <section
            class="col-span-2 bg-s-surface border border-s-border rounded-lg p-4 flex flex-col gap-3 min-w-0"
          >
            <header class="flex flex-wrap items-baseline justify-between gap-2">
              <h2
                class="text-xs font-medium uppercase tracking-wider text-s-muted"
              >
                {{ t('SYNAPSEOS.DASHBOARD.TODAY.TITLE') }}
              </h2>
              <span class="text-xs text-s-muted">
                {{ t('SYNAPSEOS.DASHBOARD.TODAY.HINT') }}
              </span>
            </header>
            <dl class="grid grid-cols-3 gap-3">
              <div
                v-for="stat in todayStats"
                :key="stat.key"
                class="flex flex-col gap-1 min-w-0"
              >
                <dt class="text-xs text-s-secondary truncate">
                  {{ stat.label }}
                </dt>
                <dd>
                  <SynapseSkeleton v-if="loading" class="h-7 w-12" />
                  <span
                    v-else
                    class="font-synapse-display text-2xl font-semibold text-s-primary tabular-nums"
                  >
                    {{ stat.value }}
                  </span>
                </dd>
              </div>
            </dl>
          </section>
        </div>

        <div class="grid grid-cols-1 lg:grid-cols-3 gap-4">
          <DashboardFunnel :funnel="summary?.funnel" :loading="loading" />
          <DashboardActivityChart
            :daily="daily"
            :loading="loading"
            class="lg:col-span-2"
          />
        </div>

        <div class="grid grid-cols-1 lg:grid-cols-2 gap-4">
          <DashboardRecentAlerts
            :events="summary?.recent_events || []"
            :loading="loading"
            :now="updatedAt"
          />

          <!-- DISPAROS PROGRAMADOS HOJE (dry-run read-only; snapshot 08:00/13:30) -->
          <section
            class="bg-s-surface border border-s-border rounded-lg flex flex-col min-w-0"
          >
            <header
              class="px-4 py-3 border-b border-s-border flex items-center justify-between gap-3"
            >
              <h2 class="text-sm font-semibold text-s-primary">
                {{ t('SYNAPSEOS.DASHBOARD.DRY_RUN.TITLE') }}
              </h2>
              <span
                v-if="dryRun"
                class="text-xs font-mono text-s-muted tabular-nums"
              >
                {{ dryRunItems.length }}
              </span>
            </header>
            <div v-if="loading" class="p-4 flex flex-col gap-3">
              <SynapseSkeleton v-for="n in 4" :key="n" class="h-6 w-full" />
            </div>
            <ul
              v-else-if="dryRunItems.length"
              class="flex flex-col divide-y divide-s-border overflow-auto max-h-80"
            >
              <li
                v-for="item in dryRunItems"
                :key="item.key"
                class="flex items-center gap-3 px-4 py-2.5"
              >
                <SynapseBadge :tone="item.tone">{{ item.label }}</SynapseBadge>
                <span
                  class="text-sm font-medium text-s-primary truncate flex-1"
                >
                  {{ item.name }}
                </span>
                <span class="text-xs font-mono text-s-muted tabular-nums">
                  {{
                    t('SYNAPSEOS.DASHBOARD.DRY_RUN.PHONE_END', {
                      digits: item.tel4,
                    })
                  }}
                </span>
              </li>
            </ul>
            <SynapseEmptyState
              v-else
              icon="i-lucide-send"
              :title="t('SYNAPSEOS.DASHBOARD.DRY_RUN.EMPTY_TITLE')"
              :description="t('SYNAPSEOS.DASHBOARD.DRY_RUN.EMPTY_DESC')"
              size="sm"
              class="px-4"
            />
          </section>
        </div>
      </template>
    </div>
  </div>
</template>
