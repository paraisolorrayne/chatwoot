<script setup>
// CUSTOMIZAÇÃO_SYNAPSEOS: painel agentic embutido, só para a equipe Dexi.
// Protocolo com o iframe (origem conferida dos dois lados):
//   painel → chat  { type: 'synapse-panel:ready', authenticated }
//   chat → painel  { type: 'synapse-panel:theme', theme: 'dark' | 'light' }
//   chat → painel  { type: 'synapse-panel:sso', token }  (só se authenticated = false)
import { onBeforeUnmount, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useMapGetter } from 'dashboard/composables/store';
import {
  SYNAPSEOS_PANEL_ORIGIN,
  SYNAPSEOS_PANEL_URL,
  openPanelInNewTab,
} from 'dashboard/helper/synapseos/panel';

const { t } = useI18n();
const currentUser = useMapGetter('getCurrentUser');

const currentTheme = () =>
  document.documentElement.classList.contains('dark') ? 'dark' : 'light';

const frame = ref(null);
const src = `${SYNAPSEOS_PANEL_URL}/?embed=1&theme=${currentTheme()}`;

const post = message =>
  frame.value?.contentWindow?.postMessage(message, SYNAPSEOS_PANEL_ORIGIN);

const onMessage = event => {
  if (event.origin !== SYNAPSEOS_PANEL_ORIGIN) return;
  if (event.source !== frame.value?.contentWindow) return;
  if (event.data?.type !== 'synapse-panel:ready') return;
  post({ type: 'synapse-panel:theme', theme: currentTheme() });
  if (event.data.authenticated === false) {
    post({ type: 'synapse-panel:sso', token: currentUser.value?.access_token });
  }
};

const themeObserver = new MutationObserver(() =>
  post({ type: 'synapse-panel:theme', theme: currentTheme() })
);

onMounted(() => {
  window.addEventListener('message', onMessage);
  themeObserver.observe(document.documentElement, {
    attributes: true,
    attributeFilter: ['class'],
  });
});

onBeforeUnmount(() => {
  window.removeEventListener('message', onMessage);
  themeObserver.disconnect();
});
</script>

<template>
  <section class="flex flex-col w-full h-full min-w-0 bg-s-bg">
    <header
      class="flex items-center gap-3 px-4 h-12 flex-shrink-0 border-b border-s-border"
    >
      <h1 class="font-synapse-display text-base font-semibold text-s-primary">
        {{ t('SYNAPSEOS.PLATFORM.TITLE') }}
      </h1>
      <span class="hidden sm:inline text-xs text-s-muted">
        {{ t('SYNAPSEOS.PLATFORM.STAFF_ONLY') }}
      </span>
      <button
        type="button"
        class="reset-base ms-auto inline-flex items-center gap-1.5 text-sm text-s-brand-text hover:underline focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-focus rounded"
        @click="openPanelInNewTab(currentUser?.access_token)"
      >
        {{ t('SYNAPSEOS.PLATFORM.OPEN_NEW_TAB') }}
        <span class="i-lucide-external-link size-3.5" aria-hidden="true" />
      </button>
    </header>
    <iframe
      ref="frame"
      :src="src"
      :title="t('SYNAPSEOS.PLATFORM.TITLE')"
      class="flex-1 w-full border-0"
    />
  </section>
</template>
