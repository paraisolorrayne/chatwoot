<script setup>
// CUSTOMIZAÇÃO_SYNAPSEOS — StatusBadge do design system Fykos.
// Normaliza o identificador (acentos, espaços, separadores), aceita rótulo
// próprio e mostra "—" quando o estado está ausente. Estado desconhecido é neutro.
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { resolveStatus } from 'dashboard/helper/synapseos/statusBadge';

const props = defineProps({
  status: { type: String, default: '' },
  label: { type: String, default: '' },
  stageType: { type: String, default: '' },
  size: { type: String, default: 'md' }, // sm | md
  dot: { type: Boolean, default: true },
});

const { t } = useI18n();

const VARIANT_CLASSES = {
  info: { box: 'bg-s-info-soft text-s-info-text', dot: 'bg-s-info' },
  primary: { box: 'bg-s-brand-soft text-s-brand-text', dot: 'bg-s-brand' },
  warning: {
    box: 'bg-s-warning-soft text-s-warning-text',
    dot: 'bg-s-warning',
  },
  success: {
    box: 'bg-s-success-soft text-s-success-text',
    dot: 'bg-s-success',
  },
  danger: { box: 'bg-s-error-soft text-s-error-text', dot: 'bg-s-error' },
  sombra: { box: 'bg-s-sombra-soft text-s-sombra-text', dot: 'bg-s-sombra' },
  neutral: { box: 'bg-s-subtle text-s-secondary', dot: 'bg-s-muted' },
};

const SIZE_CLASSES = {
  sm: 'text-xs h-5 px-1.5 gap-1',
  md: 'text-xs h-6 px-2 gap-1.5',
};

const resolved = computed(() =>
  resolveStatus(props.status, { stageType: props.stageType })
);

const variant = computed(() => resolved.value?.variant || 'neutral');

const text = computed(() => {
  if (props.label) return props.label;
  if (!resolved.value) return '—';
  if (resolved.value.label)
    return t(`SYNAPSEOS.STATUS.${resolved.value.label}`);
  return props.status;
});
</script>

<template>
  <span
    class="inline-flex items-center rounded-full font-medium whitespace-nowrap"
    :class="[VARIANT_CLASSES[variant].box, SIZE_CLASSES[size]]"
  >
    <span
      v-if="dot && resolved"
      class="size-1.5 rounded-full shrink-0"
      :class="VARIANT_CLASSES[variant].dot"
    />
    {{ text }}
  </span>
</template>
