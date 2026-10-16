<script setup>
// CUSTOMIZAÇÃO_SYNAPSEOS: cartão de seção da Inteligência, com carregamento e
// erro próprios (uma seção fora do ar não derruba a página).
import SynapseButton from 'next/synapseos/SynapseButton.vue';
import SynapseSkeleton from 'next/synapseos/SynapseSkeleton.vue';

defineProps({
  title: { type: String, required: true },
  description: { type: String, default: '' },
  loading: { type: Boolean, default: false },
  error: { type: String, default: '' },
  retryLabel: { type: String, default: '' },
});

const emit = defineEmits(['retry']);
</script>

<template>
  <section
    class="flex flex-col gap-4 rounded-xl border border-s-border bg-s-surface p-4 md:p-5 min-w-0"
  >
    <header class="flex flex-col gap-1">
      <h2 class="font-synapse-display text-base font-semibold text-s-primary">
        {{ title }}
      </h2>
      <p v-if="description" class="text-sm text-s-muted">{{ description }}</p>
    </header>
    <div
      v-if="error"
      role="alert"
      class="flex flex-wrap items-center gap-3 rounded-lg bg-s-error-soft text-s-error-text px-3 py-2 text-sm"
    >
      <span
        class="i-lucide-triangle-alert size-4 shrink-0"
        aria-hidden="true"
      />
      <span class="flex-1 min-w-0">{{ error }}</span>
      <SynapseButton
        variant="outline"
        size="sm"
        icon="i-lucide-refresh-cw"
        @click="emit('retry')"
      >
        {{ retryLabel }}
      </SynapseButton>
    </div>
    <div v-else-if="loading" class="flex flex-col gap-3" aria-busy="true">
      <SynapseSkeleton class="h-5 w-2/3" />
      <SynapseSkeleton class="h-5 w-full" />
      <SynapseSkeleton class="h-5 w-5/6" />
    </div>
    <slot v-else />
  </section>
</template>
