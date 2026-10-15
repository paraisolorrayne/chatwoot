<script setup>
import { computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute } from 'vue-router';
import SynapseCard from 'next/synapseos/SynapseCard.vue';
import SynapseButton from 'next/synapseos/SynapseButton.vue';
import SynapseStatusPill from 'next/synapseos/SynapseStatusPill.vue';
import SynapseQuotaBar from 'next/synapseos/SynapseQuotaBar.vue';
import SynapsePageHeader from 'next/synapseos/SynapsePageHeader.vue';
import SynapseSkeleton from 'next/synapseos/SynapseSkeleton.vue';
import { agentClasses } from 'dashboard/helper/synapseos/agentIdentity';
import {
  useAgentMetricsStore,
  RANGE_OPTIONS,
} from 'dashboard/store/synapseos/useAgentMetrics';
import {
  formatBRL,
  formatPercent,
  formatSeconds,
  formatCount,
} from 'dashboard/helper/synapseos/metricsFormatters';

const { t } = useI18n();
const route = useRoute();
const store = useAgentMetricsStore();

const accountId = computed(() => route.params.accountId);

// Agent card declarative configuration.
// Each card has: slug, icon, tone, hero KPI (large), secondary KPIs (smaller rows).
const AGENT_CARDS = {
  natalia: {
    icon: 'i-lucide-message-circle',
    tone: 'brand',
    hero: { key: 'conversas_atendidas', format: 'count' },
    secondary: [
      { key: 'mensagens_enviadas', format: 'count' },
      { key: 'taxa_resposta_cliente', format: 'percent' },
    ],
  },
  alice: {
    icon: 'i-lucide-target',
    tone: 'brand',
    hero: { key: 'leads_frios_contactados', format: 'count' },
    secondary: [
      { key: 'taxa_resposta', format: 'percent' },
      { key: 'leads_convertidos', format: 'count' },
    ],
  },
  iza: {
    icon: 'i-lucide-sparkles',
    tone: 'brand',
    hero: { key: 'leads_inbound_recepcionados', format: 'count' },
    secondary: [
      { key: 'speed_to_lead_seconds', format: 'seconds' },
      { key: 'taxa_qualificacao', format: 'percent' },
      { key: 'handoffs', format: 'count' },
    ],
  },
  otto: {
    icon: 'i-lucide-bot',
    tone: 'brand',
    hero: { key: 'interacoes_crm', format: 'count' },
    secondary: [
      { key: 'alertas_sla', format: 'count' },
      { key: 'resgates', format: 'count' },
    ],
  },
  luis: {
    icon: 'i-lucide-wrench',
    tone: 'info',
    hero: { key: 'assistencias_tecnicas', format: 'count' },
    secondary: [],
  },
  fernanda: {
    icon: 'i-lucide-life-buoy',
    tone: 'success',
    hero: { key: 'pipeline_resgatado_cents', format: 'brl' },
    secondary: [{ key: 'leads_reativados', format: 'count' }],
  },
  angela: {
    icon: 'i-lucide-calendar-check',
    tone: 'warning',
    hero: { key: 'agendamentos', format: 'count' },
    secondary: [{ key: 'taxa_crosssell', format: 'percent' }],
  },
  vitor: {
    icon: 'i-lucide-hand-coins',
    tone: 'success',
    hero: { key: 'valor_recuperado_cents', format: 'brl' },
    secondary: [{ key: 'acordos_fechados', format: 'count' }],
  },
};

// CUSTOMIZAÇÃO_SYNAPSEOS: classes literais por tom (o Tailwind não gera
// classes montadas dinamicamente, como `text-s-${tone}-text`).
const TONE_CLASSES = {
  brand: 'bg-s-brand-soft text-s-brand-text',
  info: 'bg-s-info-soft text-s-info-text',
  success: 'bg-s-success-soft text-s-success-text',
  warning: 'bg-s-warning-soft text-s-warning-text',
};

const GROUPS = [
  // Natália aparece primeiro na FRONTLINE — é o template base de SDR usado
  // em clientes que não cabem em squadron especializado (Audi, Royal Enfield).
  { key: 'FRONTLINE', slugs: ['natalia', 'alice', 'iza'] },
  { key: 'PARTNERS', slugs: ['otto', 'luis'] },
  { key: 'RESCUE', slugs: ['fernanda', 'angela', 'vitor'] },
];

// Apenas grupos com pelo menos um agente ativo aparecem; cada grupo
// só lista os slugs ativos (cadastrados como AgentBot na conta).
const visibleGroups = computed(() =>
  GROUPS.map(g => ({
    ...g,
    slugs: g.slugs.filter(s => store.activeSlugs.includes(s)),
  })).filter(g => g.slugs.length > 0)
);

const formatKpi = (format, value) => {
  if (format === 'brl') return formatBRL(value);
  if (format === 'percent') return formatPercent(value);
  if (format === 'seconds') return formatSeconds(value);
  return formatCount(value);
};

// Whether the hero/secondary KPI is a money or percentage one — drives visual priority.
const isHighlightFormat = format => format === 'brl' || format === 'percent';

const i18nAgentKey = slug => slug.toUpperCase();

const agentDisplayName = slug =>
  store.agents[slug]?.displayName ||
  t(`SYNAPSEOS.METRICS.AGENTS.${i18nAgentKey(slug)}.NAME`);

const kpiLabel = (slug, key) =>
  t(`SYNAPSEOS.METRICS.AGENTS.${i18nAgentKey(slug)}.KPI.${key.toUpperCase()}`);

const refreshing = computed(() =>
  store.activeSlugs.some(slug => store.agents[slug].isLoading)
);

const refreshAll = () => store.fetchAll({ accountId: accountId.value });

const selectRange = rangeKey => {
  store.range = rangeKey;
  store.since = new Date(
    Date.now() -
      (RANGE_OPTIONS.find(r => r.key === rangeKey)?.hours || 720) * 3600 * 1000
  ).toISOString();
  refreshAll();
};

onMounted(refreshAll);
</script>

<template>
  <div
    class="bg-s-bg p-4 md:p-8 space-y-8 h-full w-full flex-1 min-w-0 overflow-auto"
  >
    <SynapsePageHeader
      :title="t('SYNAPSEOS.METRICS.TITLE')"
      :description="t('SYNAPSEOS.METRICS.SUBTITLE')"
      :updated-at="store.lastUpdatedAt"
      :refreshing="refreshing"
    >
      <template #actions>
        <div
          class="inline-flex rounded-lg border border-s-border bg-s-surface p-0.5"
          role="group"
          :aria-label="t('SYNAPSEOS.METRICS.RANGE_LABEL')"
        >
          <button
            v-for="r in RANGE_OPTIONS"
            :key="r.key"
            type="button"
            class="px-3 h-8 text-xs font-medium rounded-md transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-s-focus"
            :class="[
              store.range === r.key
                ? 'bg-s-brand-soft text-s-brand-text'
                : 'text-s-secondary hover:bg-s-subtle',
            ]"
            :aria-pressed="store.range === r.key"
            @click="selectRange(r.key)"
          >
            {{ t(r.labelKey) }}
          </button>
        </div>
        <SynapseButton
          variant="outline"
          size="sm"
          icon="i-lucide-refresh-cw"
          :loading="refreshing"
          @click="refreshAll"
        >
          {{ t('SYNAPSEOS.METRICS.REFRESH') }}
        </SynapseButton>
      </template>
    </SynapsePageHeader>

    <!-- Empty state: nenhum AgentBot cadastrado pra essa conta -->
    <div
      v-if="store.activeFetched && !store.hasActiveAgents"
      class="flex flex-col items-center justify-center text-center py-16 px-6 gap-3 rounded-xl border border-dashed border-s-border bg-s-surface"
    >
      <span class="i-lucide-users size-8 text-s-muted" />
      <h2 class="text-lg font-semibold text-s-primary">
        {{ t('SYNAPSEOS.METRICS.EMPTY_STATE.TITLE') }}
      </h2>
      <p class="text-sm text-s-muted max-w-md">
        {{ t('SYNAPSEOS.METRICS.EMPTY_STATE.DESCRIPTION') }}
      </p>
    </div>

    <section v-for="group in visibleGroups" :key="group.key" class="space-y-4">
      <div class="flex items-center gap-3">
        <h2 class="text-lg font-semibold text-s-primary">
          {{ t(`SYNAPSEOS.METRICS.GROUPS.${group.key}`) }}
        </h2>
        <span class="h-px flex-1 bg-s-border-subtle" />
        <SynapseStatusPill tone="neutral" size="sm">
          {{ t('SYNAPSEOS.METRICS.AGENT_COUNT', group.slugs.length) }}
        </SynapseStatusPill>
      </div>

      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-5">
        <SynapseCard v-for="slug in group.slugs" :key="slug" padding="none">
          <div class="p-6 flex flex-col gap-5">
            <!-- Header: icon + agent name + status chip -->
            <div class="flex items-start justify-between gap-3">
              <div class="flex items-center gap-3 min-w-0">
                <span
                  class="inline-flex items-center justify-center size-10 rounded-xl shrink-0"
                  :class="TONE_CLASSES[AGENT_CARDS[slug].tone]"
                >
                  <span class="size-5" :class="[AGENT_CARDS[slug].icon]" />
                </span>
                <div class="flex flex-col min-w-0">
                  <span
                    class="inline-flex items-center gap-2 text-base font-semibold text-s-primary min-w-0"
                  >
                    <span
                      class="size-2 rounded-full shrink-0"
                      :class="agentClasses({ squadronRole: slug }).bg"
                      aria-hidden="true"
                    />
                    <span class="truncate">{{ agentDisplayName(slug) }}</span>
                  </span>
                  <span class="text-xs text-s-muted">
                    {{
                      t(`SYNAPSEOS.METRICS.AGENTS.${i18nAgentKey(slug)}.ROLE`)
                    }}
                  </span>
                </div>
              </div>
              <SynapseStatusPill
                v-if="store.agents[slug].error"
                tone="error"
                size="sm"
              >
                {{ t('SYNAPSEOS.METRICS.ERROR') }}
              </SynapseStatusPill>
            </div>

            <!-- Loading skeleton -->
            <div
              v-if="store.agents[slug].isLoading"
              class="flex flex-col gap-4"
            >
              <SynapseSkeleton class="h-12 w-1/2" />
              <SynapseSkeleton class="h-4 w-3/4" />
              <SynapseSkeleton class="h-4 w-2/3" />
            </div>

            <!-- Error -->
            <div
              v-else-if="store.agents[slug].error"
              class="text-sm text-s-error-text"
            >
              {{ t('SYNAPSEOS.METRICS.ERROR') }}
            </div>

            <!-- Data -->
            <template v-else>
              <!-- Hero KPI -->
              <div class="flex flex-col gap-1">
                <span
                  class="text-xs font-medium uppercase tracking-wider text-s-muted"
                >
                  {{ kpiLabel(slug, AGENT_CARDS[slug].hero.key) }}
                </span>
                <span
                  class="font-synapse-display font-semibold tracking-[-0.01em] leading-none tabular-nums text-[2.5rem]"
                  :class="[
                    isHighlightFormat(AGENT_CARDS[slug].hero.format)
                      ? 'text-s-brand'
                      : 'text-s-primary',
                  ]"
                >
                  {{
                    formatKpi(
                      AGENT_CARDS[slug].hero.format,
                      store.agents[slug].kpis[AGENT_CARDS[slug].hero.key]
                    )
                  }}
                </span>
              </div>

              <!-- Secondary KPIs -->
              <div
                v-if="AGENT_CARDS[slug].secondary.length"
                class="flex flex-col gap-3 pt-3 border-t border-s-border-subtle"
              >
                <div
                  v-for="kpi in AGENT_CARDS[slug].secondary"
                  :key="kpi.key"
                  class="flex items-center justify-between gap-3"
                >
                  <span class="text-sm text-s-muted">
                    {{ kpiLabel(slug, kpi.key) }}
                  </span>
                  <span
                    class="text-base font-semibold"
                    :class="[
                      isHighlightFormat(kpi.format)
                        ? 'text-s-brand-text'
                        : 'text-s-primary',
                    ]"
                  >
                    {{
                      formatKpi(kpi.format, store.agents[slug].kpis[kpi.key])
                    }}
                  </span>
                </div>
              </div>

              <!-- Consumo do mês (quota de mensagens enviadas) -->
              <div
                v-if="store.agents[slug].usage"
                class="flex flex-col gap-2 pt-3 border-t border-s-border-subtle"
              >
                <div class="flex items-center justify-between gap-3">
                  <span class="text-sm text-s-muted">
                    {{ t('SYNAPSEOS.METRICS.USAGE.LABEL') }}
                  </span>
                  <SynapseStatusPill
                    v-if="store.agents[slug].usage.over_quota"
                    tone="error"
                    size="sm"
                  >
                    {{
                      t('SYNAPSEOS.METRICS.USAGE.OVERAGE', {
                        n: formatCount(store.agents[slug].usage.overage),
                      })
                    }}
                  </SynapseStatusPill>
                </div>
                <SynapseQuotaBar
                  v-slot="{ percent }"
                  :used="store.agents[slug].usage.total"
                  :quota="store.agents[slug].usage.quota"
                >
                  <div class="flex items-center justify-between text-xs">
                    <span class="text-s-secondary">
                      <span class="font-semibold text-s-primary">{{
                        formatCount(store.agents[slug].usage.total)
                      }}</span>
                      <span class="text-s-muted">
                        / {{ formatCount(store.agents[slug].usage.quota) }}
                      </span>
                    </span>
                    <span class="text-s-muted">{{ percent }}%</span>
                  </div>
                </SynapseQuotaBar>
              </div>
            </template>
          </div>
        </SynapseCard>
      </div>
    </section>
  </div>
</template>
