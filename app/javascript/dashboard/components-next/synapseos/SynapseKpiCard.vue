<script setup>
// CUSTOMIZAÇÃO_SYNAPSEOS — KpiCard do design system Fykos.
// Card com borda (sem sombra), valor em Space Grotesk, delta com sentido
// configurável (`positiveIs`), dica, skeleton e sparkline opcionais.
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import SynapseSkeleton from './SynapseSkeleton.vue';

const props = defineProps({
  label: { type: String, required: true },
  value: { type: [String, Number], default: '' },
  icon: { type: String, default: '' },
  delta: { type: Number, default: null },
  deltaUnit: { type: String, default: '%' }, // '%' | 'pp' | ''
  deltaLabel: { type: String, default: '' },
  positiveIs: { type: String, default: 'up' }, // up | down
  hint: { type: String, default: '' },
  loading: { type: Boolean, default: false },
  size: { type: String, default: 'md' }, // md | lg
  tone: { type: String, default: 'brand' }, // brand|success|warning|error|neutral
  sparkline: { type: Array, default: () => [] },
});

const { t, locale } = useI18n();

const ICON_TONE = {
  brand: 'bg-s-brand-soft text-s-brand-text',
  success: 'bg-s-success-soft text-s-success-text',
  warning: 'bg-s-warning-soft text-s-warning-text',
  error: 'bg-s-error-soft text-s-error-text',
  neutral: 'bg-s-subtle text-s-secondary',
};

const deltaState = computed(() => {
  if (props.delta === null || props.delta === 0) return 'flat';
  const up = props.delta > 0;
  return up === (props.positiveIs === 'up') ? 'good' : 'bad';
});

const DELTA_CLASS = {
  good: 'text-s-success-text',
  bad: 'text-s-error-text',
  flat: 'text-s-muted',
};

const deltaDisplay = computed(() => {
  if (props.delta === null) return '';
  const sign = props.delta > 0 ? '+' : '';
  const number = props.delta.toLocaleString(locale.value.replace('_', '-'), {
    maximumFractionDigits: 1,
  });
  const unit = props.deltaUnit === 'pp' ? ' p.p.' : props.deltaUnit;
  return `${sign}${number}${unit}`;
});

const sparkPoints = computed(() => {
  const values = props.sparkline.map(Number).filter(v => !Number.isNaN(v));
  if (values.length < 2) return null;
  const max = Math.max(...values);
  const min = Math.min(...values);
  const range = max - min || 1;
  const step = 100 / (values.length - 1);
  return values.map((v, i) => [i * step, 28 - ((v - min) / range) * 24]);
});

const sparkLine = computed(() =>
  sparkPoints.value?.map(([x, y]) => `${x},${y}`).join(' ')
);
const sparkArea = computed(() =>
  sparkPoints.value
    ? `M0,32 L${sparkLine.value.replaceAll(' ', ' L')} L100,32 Z`
    : ''
);
const sparkEnd = computed(() => sparkPoints.value?.at(-1));
</script>

<template>
  <div
    class="bg-s-surface border border-s-border rounded-lg flex flex-col min-w-0"
    :class="size === 'lg' ? 'p-5 gap-3' : 'p-4 gap-2'"
  >
    <div class="flex items-start justify-between gap-3">
      <span class="text-xs font-medium uppercase tracking-wider text-s-muted">
        {{ label }}
      </span>
      <span
        v-if="icon"
        class="inline-flex items-center justify-center size-8 rounded-lg shrink-0"
        :class="ICON_TONE[tone]"
      >
        <span class="size-4" :class="icon" />
      </span>
    </div>

    <template v-if="loading">
      <SynapseSkeleton :class="size === 'lg' ? 'h-9 w-32' : 'h-7 w-20'" />
      <SynapseSkeleton class="h-3 w-24" />
    </template>
    <template v-else>
      <div class="flex items-end justify-between gap-3">
        <span
          class="font-synapse-display font-semibold tracking-[-0.01em] text-s-primary leading-none tabular-nums truncate"
          :class="size === 'lg' ? 'text-[2rem]' : 'text-2xl'"
        >
          {{ value }}
        </span>
        <svg
          v-if="sparkPoints"
          viewBox="0 0 100 32"
          preserveAspectRatio="none"
          class="w-24 h-8 shrink-0"
          aria-hidden="true"
        >
          <path :d="sparkArea" class="fill-s-chart-1/10" />
          <polyline
            :points="sparkLine"
            fill="none"
            class="stroke-s-chart-1"
            stroke-width="1.5"
            vector-effect="non-scaling-stroke"
            stroke-linejoin="round"
          />
          <circle
            :cx="sparkEnd[0]"
            :cy="sparkEnd[1]"
            r="2"
            class="fill-s-chart-1"
          />
        </svg>
      </div>
      <div
        v-if="delta !== null || hint"
        class="flex flex-wrap items-center gap-x-1.5 gap-y-0.5 text-xs"
      >
        <span
          v-if="delta !== null"
          class="inline-flex items-center gap-0.5 font-medium tabular-nums"
          :class="DELTA_CLASS[deltaState]"
        >
          <span
            v-if="deltaState !== 'flat'"
            class="size-3.5"
            :class="
              delta > 0 ? 'i-lucide-trending-up' : 'i-lucide-trending-down'
            "
          />
          {{ deltaDisplay }}
        </span>
        <span v-if="delta !== null" class="text-s-muted">
          {{ deltaLabel || t('SYNAPSEOS.COMMON.VS_PREVIOUS_PERIOD') }}
        </span>
        <span v-if="hint" class="text-s-muted w-full">{{ hint }}</span>
      </div>
    </template>
  </div>
</template>
