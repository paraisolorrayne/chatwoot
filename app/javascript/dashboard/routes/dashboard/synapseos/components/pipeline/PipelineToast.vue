<script setup>
// CUSTOMIZAÇÃO_SYNAPSEOS — toast do board com ação opcional ("Desfazer").
// O useAlert do Chatwoot só aceita ação do tipo link, por isso este componente.
import { useI18n } from 'vue-i18n';

defineProps({
  // { id, message, tone: 'neutral' | 'error', actionLabel }
  toast: { type: Object, default: null },
});

const emit = defineEmits(['action', 'dismiss']);

const { t } = useI18n();
</script>

<template>
  <Teleport to="body">
    <div
      class="fixed inset-x-0 bottom-6 z-50 flex justify-center px-4 pointer-events-none"
      role="status"
      aria-live="polite"
    >
      <div
        v-if="toast"
        :key="toast.id"
        class="pointer-events-auto inline-flex items-center gap-3 max-w-md rounded-lg bg-s-primary px-4 py-3 text-sm text-s-inverse shadow-s-lg motion-safe:animate-s-scale-in"
      >
        <span
          v-if="toast.tone === 'error'"
          class="i-lucide-circle-alert size-4 shrink-0"
        />
        <span class="min-w-0">{{ toast.message }}</span>
        <button
          v-if="toast.actionLabel"
          type="button"
          class="shrink-0 px-1 py-0.5 font-semibold underline underline-offset-2 rounded focus:outline-none focus-visible:ring-2 focus-visible:ring-s-inverse"
          @click="emit('action')"
        >
          {{ toast.actionLabel }}
        </button>
        <button
          type="button"
          class="shrink-0 -me-1 p-1 rounded opacity-70 hover:opacity-100 focus:outline-none focus-visible:ring-2 focus-visible:ring-s-inverse"
          :aria-label="t('SYNAPSEOS.PIPELINE.CLOSE')"
          @click="emit('dismiss')"
        >
          <span class="i-lucide-x block size-4" />
        </button>
      </div>
    </div>
  </Teleport>
</template>
