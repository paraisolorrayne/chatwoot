<script setup>
// CUSTOMIZAÇÃO_SYNAPSEOS — atividade diária do dashboard executivo.
// Cores do design system (chartTheme) recalculadas quando o tema alterna.
// Handoffs (poucos por dia) ficam em barras num eixo secundário para não
// sumirem perto do volume de mensagens.
import { ref, computed, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import Chart from 'primevue/chart';
import SynapseSkeleton from 'next/synapseos/SynapseSkeleton.vue';
import SynapseEmptyState from 'next/synapseos/SynapseEmptyState.vue';
import {
  baseChartOptions,
  chartTheme,
  cssColor,
  useThemeKey,
} from 'dashboard/helper/synapseos/chartTheme';
import { useDashboardFormat } from './useDashboardFormat';

const props = defineProps({
  daily: { type: Array, default: () => [] },
  loading: { type: Boolean, default: false },
});

const { t } = useI18n();
const { formatDayMonth } = useDashboardFormat();

const themeKey = useThemeKey();
const theme = ref(chartTheme());
const baseOptions = ref(baseChartOptions());
watch(themeKey, () => {
  theme.value = chartTheme();
  baseOptions.value = baseChartOptions();
});

const hasActivity = computed(() =>
  props.daily.some(
    d =>
      d.messages_received ||
      d.messages_sent ||
      d.ai_responses ||
      d.bot_takeovers
  )
);

const line = (label, data, color, extra = {}) => ({
  type: 'line',
  label,
  data,
  borderColor: color,
  backgroundColor: color,
  pointBackgroundColor: color,
  borderWidth: 2,
  tension: 0.3,
  pointRadius: 0,
  pointHoverRadius: 3,
  order: 1,
  ...extra,
});

const chartData = computed(() => {
  const { series } = theme.value;
  const days = props.daily;
  return {
    labels: days.map(d => formatDayMonth(d.date)),
    datasets: [
      line(
        t('SYNAPSEOS.DASHBOARD.CHART.MESSAGES_RECEIVED'),
        days.map(d => d.messages_received),
        series[0],
        { fill: true, backgroundColor: cssColor('chart-1', 0.08) }
      ),
      line(
        t('SYNAPSEOS.DASHBOARD.CHART.MESSAGES_SENT'),
        days.map(d => d.messages_sent),
        series[7]
      ),
      line(
        t('SYNAPSEOS.DASHBOARD.CHART.AI_RESPONSES'),
        days.map(d => d.ai_responses),
        series[6],
        { borderDash: [4, 4], borderWidth: 1.5 }
      ),
      {
        type: 'bar',
        label: t('SYNAPSEOS.DASHBOARD.CHART.BOT_TAKEOVERS'),
        data: days.map(d => d.bot_takeovers),
        backgroundColor: cssColor('chart-2', 0.7),
        borderWidth: 0,
        borderRadius: 3,
        maxBarThickness: 14,
        yAxisID: 'y1',
        order: 2,
      },
    ],
  };
});

const chartOptions = computed(() => {
  const base = baseOptions.value;
  const axisTitle = text => ({
    display: true,
    text,
    color: theme.value.muted,
    font: base.scales.y.ticks.font,
  });
  return {
    ...base,
    scales: {
      x: base.scales.x,
      y: {
        ...base.scales.y,
        title: axisTitle(t('SYNAPSEOS.DASHBOARD.CHART.AXIS_VOLUME')),
      },
      y1: {
        ...base.scales.y,
        position: 'right',
        grid: { drawOnChartArea: false },
        title: axisTitle(t('SYNAPSEOS.DASHBOARD.CHART.BOT_TAKEOVERS')),
      },
    },
  };
});
</script>

<template>
  <section
    class="bg-s-surface border border-s-border rounded-lg flex flex-col min-w-0"
  >
    <header class="px-4 py-3 border-b border-s-border">
      <h2 class="text-sm font-semibold text-s-primary">
        {{ t('SYNAPSEOS.DASHBOARD.CHART.TITLE') }}
      </h2>
    </header>
    <div class="p-4 h-80">
      <SynapseSkeleton v-if="loading" class="h-full w-full" />
      <Chart
        v-else-if="hasActivity"
        type="bar"
        :data="chartData"
        :options="chartOptions"
        class="h-full"
      />
      <SynapseEmptyState
        v-else
        icon="i-lucide-line-chart"
        :title="t('SYNAPSEOS.DASHBOARD.EMPTY_CHART_TITLE')"
        :description="t('SYNAPSEOS.DASHBOARD.EMPTY_CHART_DESCRIPTION')"
        size="sm"
      />
    </div>
  </section>
</template>
