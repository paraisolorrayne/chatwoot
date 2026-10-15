<script setup>
// CUSTOMIZAÇÃO_SYNAPSEOS — vitrine do design system Fykos (admin-only).
// Swatches usam as classes `bg-s-*` (sem hex), então acompanham os tokens de
// `_synapseos_tokens.scss` e o tema claro/escuro. Classes literais para o
// Tailwind gerar.
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import SynapsePageHeader from 'next/synapseos/SynapsePageHeader.vue';
import SynapseKpiCard from 'next/synapseos/SynapseKpiCard.vue';
import SynapseStatusBadge from 'next/synapseos/SynapseStatusBadge.vue';
import SynapseSkeleton from 'next/synapseos/SynapseSkeleton.vue';
import SynapseButton from 'next/synapseos/SynapseButton.vue';
import { agentClasses } from 'dashboard/helper/synapseos/agentIdentity';
import { useDashboardFormat } from '../components/dashboard/useDashboardFormat';

const { t } = useI18n();
const { formatNumber, formatPercent, formatCurrency } = useDashboardFormat();

const now = Date.now();

const tokenName = cls => cls.replace(/^(bg|text)-/, '');
const swatches = classes => classes.map(cls => ({ cls, name: tokenName(cls) }));

const agentSwatch = (slug, label) => {
  const cls = agentClasses({ squadronRole: slug }).bg;
  return { cls, name: tokenName(cls), label };
};

const colorGroups = computed(() => [
  {
    key: 'surfaces',
    title: t('SYNAPSEOS.DESIGN_SYSTEM.GROUPS.SURFACES'),
    swatches: swatches([
      'bg-s-bg',
      'bg-s-surface',
      'bg-s-surface-raised',
      'bg-s-subtle',
      'bg-s-hover',
      'bg-s-sidebar',
      'bg-s-border-subtle',
      'bg-s-border',
      'bg-s-border-strong',
    ]),
  },
  {
    key: 'text',
    title: t('SYNAPSEOS.DESIGN_SYSTEM.GROUPS.TEXT'),
    text: true,
    swatches: swatches([
      'text-s-primary',
      'text-s-secondary',
      'text-s-muted',
      'text-s-disabled',
      'text-s-brand-text',
    ]),
  },
  {
    key: 'brand',
    title: t('SYNAPSEOS.DESIGN_SYSTEM.GROUPS.BRAND'),
    swatches: swatches([
      'bg-s-brand-cta',
      'bg-s-brand-cta-hover',
      'bg-s-on-primary',
      'bg-s-brand',
      'bg-s-brand-700',
      'bg-s-brand-900',
      'bg-s-brand-soft',
      'bg-s-brand-soft-hover',
      'bg-s-accent',
      'bg-s-focus',
    ]),
  },
  {
    key: 'states',
    title: t('SYNAPSEOS.DESIGN_SYSTEM.GROUPS.STATES'),
    swatches: swatches([
      'bg-s-success',
      'bg-s-success-soft',
      'bg-s-success-text',
      'bg-s-warning',
      'bg-s-warning-soft',
      'bg-s-warning-text',
      'bg-s-error',
      'bg-s-error-soft',
      'bg-s-error-text',
      'bg-s-info',
      'bg-s-info-soft',
      'bg-s-info-text',
      'bg-s-sombra',
      'bg-s-sombra-soft',
      'bg-s-sombra-text',
    ]),
  },
  {
    key: 'chart',
    title: t('SYNAPSEOS.DESIGN_SYSTEM.GROUPS.CHART'),
    swatches: [
      ['bg-s-chart-1', t('SYNAPSEOS.DESIGN_SYSTEM.CHART_ROLES.CHART_1')],
      ['bg-s-chart-2', t('SYNAPSEOS.DESIGN_SYSTEM.CHART_ROLES.CHART_2')],
      ['bg-s-chart-3', t('SYNAPSEOS.DESIGN_SYSTEM.CHART_ROLES.CHART_3')],
      ['bg-s-chart-4', t('SYNAPSEOS.DESIGN_SYSTEM.CHART_ROLES.CHART_4')],
      ['bg-s-chart-5', t('SYNAPSEOS.DESIGN_SYSTEM.CHART_ROLES.CHART_5')],
      ['bg-s-chart-6', t('SYNAPSEOS.DESIGN_SYSTEM.CHART_ROLES.CHART_6')],
      ['bg-s-chart-7', t('SYNAPSEOS.DESIGN_SYSTEM.CHART_ROLES.CHART_7')],
      ['bg-s-chart-8', t('SYNAPSEOS.DESIGN_SYSTEM.CHART_ROLES.CHART_8')],
    ].map(([cls, label]) => ({ cls, name: tokenName(cls), label })),
  },
  {
    key: 'agents',
    title: t('SYNAPSEOS.DESIGN_SYSTEM.GROUPS.AGENTS'),
    swatches: [
      agentSwatch('natalia', t('SYNAPSEOS.METRICS.AGENTS.NATALIA.NAME')),
      agentSwatch('alice', t('SYNAPSEOS.METRICS.AGENTS.ALICE.NAME')),
      agentSwatch('iza', t('SYNAPSEOS.METRICS.AGENTS.IZA.NAME')),
      agentSwatch('luis', t('SYNAPSEOS.METRICS.AGENTS.LUIS.NAME')),
      agentSwatch('otto', t('SYNAPSEOS.METRICS.AGENTS.OTTO.NAME')),
      agentSwatch('fernanda', t('SYNAPSEOS.METRICS.AGENTS.FERNANDA.NAME')),
      agentSwatch('angela', t('SYNAPSEOS.METRICS.AGENTS.ANGELA.NAME')),
      agentSwatch('vitor', t('SYNAPSEOS.METRICS.AGENTS.VITOR.NAME')),
    ],
  },
]);

const fonts = computed(() => [
  {
    key: 'display',
    cls: 'font-synapse-display text-2xl font-semibold',
    label: t('SYNAPSEOS.DESIGN_SYSTEM.FONTS.DISPLAY'),
  },
  {
    key: 'sans',
    cls: 'font-sans text-base',
    label: t('SYNAPSEOS.DESIGN_SYSTEM.FONTS.SANS'),
  },
  {
    key: 'mono',
    cls: 'font-mono text-sm',
    label: t('SYNAPSEOS.DESIGN_SYSTEM.FONTS.MONO'),
  },
]);

const kpiExamples = computed(() => [
  {
    key: 'up',
    label: t('SYNAPSEOS.DASHBOARD.KPI.DEALS_WON'),
    value: formatNumber(42),
    icon: 'i-lucide-trophy',
    tone: 'success',
    delta: 12.5,
    sparkline: [3, 5, 4, 6, 8, 7, 9],
  },
  {
    key: 'down',
    label: t('SYNAPSEOS.DASHBOARD.KPI.REVENUE'),
    value: formatCurrency(1240000, { compact: true }),
    icon: 'i-lucide-banknote',
    tone: 'success',
    delta: -8.3,
  },
  {
    key: 'positive-down',
    label: t('SYNAPSEOS.DASHBOARD.KPI.DEALS_LOST'),
    value: formatNumber(7),
    icon: 'i-lucide-circle-x',
    tone: 'neutral',
    delta: -15,
    positiveIs: 'down',
  },
  {
    key: 'pp',
    label: t('SYNAPSEOS.DASHBOARD.KPI.CONVERSION_RATE'),
    value: formatPercent(12.5),
    icon: 'i-lucide-filter',
    tone: 'brand',
    delta: 1.8,
    deltaUnit: 'pp',
    hint: t('SYNAPSEOS.DASHBOARD.KPI.CONVERSION_RATE_HINT'),
  },
  {
    key: 'loading',
    label: t('SYNAPSEOS.DASHBOARD.KPI.SHOOTS_PERIOD'),
    icon: 'i-lucide-send',
    tone: 'neutral',
    loading: true,
  },
]);

// Um estado por variante do StatusBadge (+ estado ausente, que vira "—").
const STATUS_EXAMPLES = [
  'lead_novo',
  'em_atendimento',
  'negociacao',
  'venda',
  'encerrado',
  'sombra',
  'sem_resposta',
  '',
];
</script>

<template>
  <div
    class="bg-s-bg min-h-full w-full flex-1 min-w-0 p-4 md:p-8 flex flex-col gap-10 overflow-auto"
  >
    <SynapsePageHeader
      :title="t('SYNAPSEOS.DESIGN_SYSTEM.TITLE')"
      :description="t('SYNAPSEOS.DESIGN_SYSTEM.DESCRIPTION')"
    />

    <section class="flex flex-col gap-6">
      <h2 class="font-synapse-display text-lg font-semibold text-s-primary">
        {{ t('SYNAPSEOS.DESIGN_SYSTEM.SECTIONS.COLORS') }}
      </h2>
      <div
        v-for="group in colorGroups"
        :key="group.key"
        class="flex flex-col gap-3"
      >
        <h3 class="text-xs font-medium uppercase tracking-wider text-s-muted">
          {{ group.title }}
        </h3>
        <div
          class="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-6 gap-3"
        >
          <div
            v-for="swatch in group.swatches"
            :key="swatch.cls"
            class="flex flex-col gap-1.5 min-w-0"
          >
            <span
              v-if="group.text"
              class="h-12 rounded-lg border border-s-border bg-s-surface flex items-center justify-center font-synapse-display text-xl font-semibold"
              :class="swatch.cls"
            >
              {{ t('SYNAPSEOS.DESIGN_SYSTEM.TEXT_SAMPLE') }}
            </span>
            <span
              v-else
              class="h-12 rounded-lg border border-s-border"
              :class="swatch.cls"
            />
            <span class="text-xs font-mono text-s-primary truncate">
              {{ swatch.name }}
            </span>
            <span v-if="swatch.label" class="text-xs text-s-muted truncate">
              {{ swatch.label }}
            </span>
          </div>
        </div>
      </div>
    </section>

    <section class="flex flex-col gap-4">
      <h2 class="font-synapse-display text-lg font-semibold text-s-primary">
        {{ t('SYNAPSEOS.DESIGN_SYSTEM.SECTIONS.TYPOGRAPHY') }}
      </h2>
      <div
        class="bg-s-surface border border-s-border rounded-lg p-4 md:p-6 flex flex-col gap-5"
      >
        <div v-for="font in fonts" :key="font.key" class="flex flex-col gap-1">
          <span class="text-xs text-s-muted">{{ font.label }}</span>
          <span class="text-s-primary" :class="font.cls">
            {{ t('SYNAPSEOS.DESIGN_SYSTEM.TYPE_SAMPLE') }}
          </span>
        </div>
      </div>
    </section>

    <section class="flex flex-col gap-4">
      <h2 class="font-synapse-display text-lg font-semibold text-s-primary">
        {{ t('SYNAPSEOS.DESIGN_SYSTEM.SECTIONS.PAGE_HEADER') }}
      </h2>
      <div
        class="bg-s-surface border border-s-border rounded-lg p-4 md:p-6 flex flex-col gap-6"
      >
        <SynapsePageHeader
          :title="t('SYNAPSEOS.DESIGN_SYSTEM.EXAMPLES.PAGE_TITLE')"
          :description="t('SYNAPSEOS.DESIGN_SYSTEM.EXAMPLES.PAGE_DESCRIPTION')"
          :updated-at="now"
        >
          <template #actions>
            <SynapseButton variant="outline" size="sm" icon="i-lucide-download">
              {{ t('SYNAPSEOS.DESIGN_SYSTEM.EXAMPLES.ACTION') }}
            </SynapseButton>
          </template>
        </SynapsePageHeader>
        <SynapsePageHeader
          :title="t('SYNAPSEOS.DESIGN_SYSTEM.EXAMPLES.PAGE_TITLE')"
          :description="t('SYNAPSEOS.DESIGN_SYSTEM.EXAMPLES.PAGE_DESCRIPTION')"
          :updated-at="now"
          refreshing
        />
      </div>
    </section>

    <section class="flex flex-col gap-4">
      <h2 class="font-synapse-display text-lg font-semibold text-s-primary">
        {{ t('SYNAPSEOS.DESIGN_SYSTEM.SECTIONS.KPI_CARD') }}
      </h2>
      <div class="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-5 gap-4">
        <SynapseKpiCard
          v-for="kpi in kpiExamples"
          :key="kpi.key"
          :label="kpi.label"
          :value="kpi.value"
          :icon="kpi.icon"
          :tone="kpi.tone"
          :delta="kpi.delta ?? null"
          :delta-unit="kpi.deltaUnit"
          :positive-is="kpi.positiveIs"
          :hint="kpi.hint"
          :sparkline="kpi.sparkline"
          :loading="kpi.loading"
        />
      </div>
    </section>

    <section class="flex flex-col gap-4">
      <h2 class="font-synapse-display text-lg font-semibold text-s-primary">
        {{ t('SYNAPSEOS.DESIGN_SYSTEM.SECTIONS.STATUS_BADGE') }}
      </h2>
      <div
        class="bg-s-surface border border-s-border rounded-lg p-4 md:p-6 flex flex-col gap-3"
      >
        <div class="flex flex-wrap gap-2">
          <SynapseStatusBadge
            v-for="status in STATUS_EXAMPLES"
            :key="status"
            :status="status"
          />
        </div>
        <div class="flex flex-wrap gap-2">
          <SynapseStatusBadge
            v-for="status in STATUS_EXAMPLES"
            :key="status"
            :status="status"
            size="sm"
          />
        </div>
      </div>
    </section>

    <section class="flex flex-col gap-4">
      <h2 class="font-synapse-display text-lg font-semibold text-s-primary">
        {{ t('SYNAPSEOS.DESIGN_SYSTEM.SECTIONS.SKELETON') }}
      </h2>
      <div
        class="bg-s-surface border border-s-border rounded-lg p-4 md:p-6 flex flex-col gap-3"
      >
        <SynapseSkeleton class="h-8 w-32" />
        <SynapseSkeleton class="h-4 w-3/4" />
        <SynapseSkeleton class="h-4 w-1/2" />
      </div>
    </section>

    <section class="flex flex-col gap-4">
      <h2 class="font-synapse-display text-lg font-semibold text-s-primary">
        {{ t('SYNAPSEOS.DESIGN_SYSTEM.SECTIONS.BUTTONS') }}
      </h2>
      <div
        class="bg-s-surface border border-s-border rounded-lg p-4 md:p-6 flex flex-col gap-4"
      >
        <div class="flex flex-wrap gap-3">
          <SynapseButton variant="primary" icon="i-lucide-plus">
            {{ t('SYNAPSEOS.DESIGN_SYSTEM.BUTTONS.PRIMARY') }}
          </SynapseButton>
          <SynapseButton variant="outline">
            {{ t('SYNAPSEOS.DESIGN_SYSTEM.BUTTONS.OUTLINE') }}
          </SynapseButton>
          <SynapseButton variant="ghost" icon="i-lucide-settings">
            {{ t('SYNAPSEOS.DESIGN_SYSTEM.BUTTONS.GHOST') }}
          </SynapseButton>
          <SynapseButton variant="danger" icon="i-lucide-trash-2">
            {{ t('SYNAPSEOS.DESIGN_SYSTEM.BUTTONS.DANGER') }}
          </SynapseButton>
          <SynapseButton variant="primary" loading>
            {{ t('SYNAPSEOS.DESIGN_SYSTEM.BUTTONS.LOADING') }}
          </SynapseButton>
          <SynapseButton variant="primary" disabled>
            {{ t('SYNAPSEOS.DESIGN_SYSTEM.BUTTONS.DISABLED') }}
          </SynapseButton>
        </div>
        <div class="flex items-end flex-wrap gap-3">
          <SynapseButton size="sm">
            {{ t('SYNAPSEOS.DESIGN_SYSTEM.BUTTONS.SMALL') }}
          </SynapseButton>
          <SynapseButton size="md">
            {{ t('SYNAPSEOS.DESIGN_SYSTEM.BUTTONS.MEDIUM') }}
          </SynapseButton>
          <SynapseButton size="lg">
            {{ t('SYNAPSEOS.DESIGN_SYSTEM.BUTTONS.LARGE') }}
          </SynapseButton>
        </div>
      </div>
    </section>
  </div>
</template>
