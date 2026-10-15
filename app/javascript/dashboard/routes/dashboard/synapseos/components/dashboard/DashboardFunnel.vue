<script setup>
// CUSTOMIZAÇÃO_SYNAPSEOS — funil do período (disparos → responderam → alertas
// → ganhos) em barras horizontais, com a conversão de cada etapa.
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import SynapseSkeleton from 'next/synapseos/SynapseSkeleton.vue';
import SynapseEmptyState from 'next/synapseos/SynapseEmptyState.vue';
import { useDashboardFormat } from './useDashboardFormat';

const props = defineProps({
  funnel: { type: Object, default: null },
  loading: { type: Boolean, default: false },
});

const { t } = useI18n();
const { formatNumber, formatPercent } = useDashboardFormat();

// chart-1 = volume; brand = etapa da Elisa (alerta); chart-2 = ganho.
const STEPS = [
  { key: 'disparos', bar: 'bg-s-chart-1' },
  { key: 'responderam', bar: 'bg-s-chart-1' },
  { key: 'alertas', bar: 'bg-s-brand' },
  { key: 'ganhos', bar: 'bg-s-chart-2' },
];

const labels = computed(() => ({
  disparos: t('SYNAPSEOS.DASHBOARD.FUNNEL.SHOOTS'),
  responderam: t('SYNAPSEOS.DASHBOARD.FUNNEL.REPLIED'),
  alertas: t('SYNAPSEOS.DASHBOARD.FUNNEL.ALERTS'),
  ganhos: t('SYNAPSEOS.DASHBOARD.FUNNEL.WON'),
}));

// Só é lido quando há disparos (ver template), então a base nunca é zero.
const steps = computed(() => {
  const { funnel } = props;
  return STEPS.map((step, index) => {
    const value = funnel[step.key];
    const previous = index > 0 ? funnel[STEPS[index - 1].key] : 0;
    return {
      ...step,
      label: labels.value[step.key],
      value: formatNumber(value),
      width: `${Math.max((value / funnel.disparos) * 100, value ? 1 : 0)}%`,
      rate: previous
        ? t('SYNAPSEOS.DASHBOARD.FUNNEL.STEP_RATE', {
            rate: formatPercent((value / previous) * 100),
          })
        : '',
    };
  });
});
</script>

<template>
  <section
    class="bg-s-surface border border-s-border rounded-lg flex flex-col min-w-0"
  >
    <header class="px-4 py-3 border-b border-s-border">
      <h2 class="text-sm font-semibold text-s-primary">
        {{ t('SYNAPSEOS.DASHBOARD.FUNNEL.TITLE') }}
      </h2>
      <p class="text-xs text-s-muted">
        {{ t('SYNAPSEOS.DASHBOARD.FUNNEL.DESCRIPTION') }}
      </p>
    </header>

    <div v-if="loading" class="p-4 flex flex-col gap-5">
      <div v-for="step in STEPS" :key="step.key" class="flex flex-col gap-2">
        <SynapseSkeleton class="h-4 w-1/2" />
        <SynapseSkeleton class="h-2 w-full" />
      </div>
    </div>

    <SynapseEmptyState
      v-else-if="!funnel?.disparos"
      icon="i-lucide-filter"
      :title="t('SYNAPSEOS.DASHBOARD.FUNNEL.EMPTY_TITLE')"
      :description="t('SYNAPSEOS.DASHBOARD.FUNNEL.EMPTY_DESCRIPTION')"
      size="sm"
      class="px-4"
    />

    <ol v-else class="p-4 flex flex-col gap-4">
      <li v-for="step in steps" :key="step.key" class="flex flex-col gap-1.5">
        <div class="flex items-baseline justify-between gap-3">
          <span class="text-sm text-s-secondary truncate">
            {{ step.label }}
          </span>
          <span class="flex items-baseline gap-2 shrink-0">
            <span v-if="step.rate" class="text-xs text-s-muted tabular-nums">
              {{ step.rate }}
            </span>
            <span
              class="font-synapse-display text-base font-semibold text-s-primary tabular-nums"
            >
              {{ step.value }}
            </span>
          </span>
        </div>
        <div
          class="h-2 rounded-full bg-s-subtle overflow-hidden"
          aria-hidden="true"
        >
          <div
            class="h-full rounded-full"
            :class="step.bar"
            :style="{ width: step.width }"
          />
        </div>
      </li>
    </ol>
  </section>
</template>
