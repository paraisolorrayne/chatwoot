<script setup>
// CUSTOMIZAÇÃO_SYNAPSEOS — PageHeader do design system Fykos: título, descrição,
// indicador de atualização e área de ações.
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';

const props = defineProps({
  title: { type: String, required: true },
  description: { type: String, default: '' },
  updatedAt: { type: [Date, Number, String], default: null },
  refreshing: { type: Boolean, default: false },
});

const { t, locale } = useI18n();

const updatedLabel = computed(() => {
  if (props.refreshing) return t('SYNAPSEOS.COMMON.REFRESHING');
  if (!props.updatedAt) return '';
  const time = new Date(props.updatedAt).toLocaleTimeString(
    locale.value.replace('_', '-'),
    { hour: '2-digit', minute: '2-digit' }
  );
  return t('SYNAPSEOS.COMMON.UPDATED_AT', { time });
});
</script>

<template>
  <header class="flex flex-wrap items-start justify-between gap-x-6 gap-y-3">
    <div class="flex flex-col gap-1 min-w-0">
      <h1
        class="font-synapse-display text-xl font-semibold tracking-[-0.01em] text-s-primary"
      >
        {{ title }}
      </h1>
      <p v-if="description" class="text-sm text-s-secondary">
        {{ description }}
      </p>
    </div>
    <div class="flex flex-wrap items-center gap-3">
      <span
        v-if="updatedLabel"
        class="inline-flex items-center gap-1.5 text-xs text-s-muted tabular-nums"
        aria-live="polite"
      >
        <span
          class="size-1.5 rounded-full"
          :class="
            refreshing
              ? 'bg-s-accent motion-safe:animate-s-skeleton'
              : 'bg-s-success'
          "
        />
        {{ updatedLabel }}
      </span>
      <slot name="actions" />
    </div>
  </header>
</template>
