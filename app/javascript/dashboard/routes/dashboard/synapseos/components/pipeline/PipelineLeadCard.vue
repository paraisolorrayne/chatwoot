<script setup>
// CUSTOMIZAÇÃO_SYNAPSEOS — card de lead do board (Fykos): modelo, valor, última
// mensagem, quem atende, tempo desde a última atualização, origem e telefone.
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import { formatPhone } from 'dashboard/helper/synapseos/phone';
import { agentClasses } from 'dashboard/helper/synapseos/agentIdentity';
import {
  elapsedLabel,
  formatBRL,
  formatDateTime,
  isStale,
  sourceLabel,
} from './pipelineHelpers';

const props = defineProps({
  lead: { type: Object, required: true },
  stage: { type: Object, default: null },
  flashing: { type: Boolean, default: false },
});

const emit = defineEmits(['open', 'moveMenu']);

const { t, locale } = useI18n();

const name = computed(() => props.lead.contact?.name || '—');
const phone = computed(() => formatPhone(props.lead.contact?.phone_number));
const amount = computed(() => formatBRL(props.lead.deal?.amount));
const source = computed(() => sourceLabel(t, props.lead.source));
const handler = computed(() => props.lead.handler);
const botDotClass = computed(
  () =>
    agentClasses({
      squadronRole: handler.value?.squadron_role,
      name: handler.value?.name,
    }).bg
);
const stale = computed(() => isStale(props.lead, props.stage));
const elapsed = computed(() => elapsedLabel(t, props.lead.updated_at));
const updatedTitle = computed(() =>
  t('SYNAPSEOS.PIPELINE.LAST_UPDATE', {
    time: formatDateTime(locale.value, props.lead.updated_at),
  })
);
</script>

<template>
  <div
    :data-lead-id="lead.id"
    tabindex="0"
    role="listitem"
    class="group/card relative bg-s-surface border border-s-border rounded-lg p-3 cursor-grab select-none transition-colors duration-150 hover:border-s-border-strong focus:outline-none focus-visible:ring-2 focus-visible:ring-focus [&.pipeline-chosen]:border-s-accent [&.pipeline-chosen]:shadow-s-md [&.pipeline-ghost]:border-dashed [&.pipeline-ghost]:border-s-accent [&.pipeline-ghost]:bg-s-brand-soft [&.pipeline-ghost]:opacity-60"
    :class="{ 'motion-safe:animate-s-flash': flashing }"
    @click="emit('open')"
    @keydown.enter.self.prevent="emit('open')"
  >
    <div class="flex items-start gap-2">
      <div class="flex-1 min-w-0 text-sm font-medium text-s-primary truncate">
        {{ name }}
      </div>
      <button
        type="button"
        class="shrink-0 -m-1 p-1 rounded-md text-s-muted hover:text-s-primary hover:bg-s-hover focus:outline-none focus-visible:ring-2 focus-visible:ring-focus"
        :aria-label="t('SYNAPSEOS.PIPELINE.MOVE_LEAD', { name })"
        aria-haspopup="menu"
        @click.stop="emit('moveMenu', $event)"
      >
        <span class="i-lucide-arrow-right-left block size-3.5" />
      </button>
    </div>

    <div
      v-if="lead.modelo_interesse || amount"
      class="mt-0.5 text-xs text-s-secondary truncate"
    >
      <span v-if="lead.modelo_interesse">{{ lead.modelo_interesse }}</span>
      <span v-if="lead.modelo_interesse && amount" aria-hidden="true"> · </span>
      <span v-if="amount" class="font-medium text-s-success-text tabular-nums">
        {{ amount }}
      </span>
    </div>

    <div
      v-if="lead.last_message"
      class="mt-1.5 text-xs text-s-muted line-clamp-2 break-words"
    >
      {{ lead.last_message.content }}
    </div>

    <div class="mt-2 flex flex-wrap items-center gap-1.5">
      <span
        v-if="handler"
        class="inline-flex items-center gap-1 max-w-full text-xs text-s-secondary"
      >
        <span
          v-if="handler.kind === 'bot'"
          class="size-2 rounded-full shrink-0"
          :class="botDotClass"
        />
        <Avatar
          v-else
          :name="handler.name"
          :src="handler.avatar_url"
          :size="16"
          rounded-full
        />
        <span class="truncate">{{ handler.name }}</span>
      </span>
      <span
        class="inline-flex items-center gap-1 h-5 px-1.5 rounded-full text-xs tabular-nums"
        :class="
          stale
            ? 'bg-s-warning-soft text-s-warning-text'
            : 'bg-s-subtle text-s-secondary'
        "
        :title="updatedTitle"
      >
        <span
          class="size-3"
          :class="stale ? 'i-lucide-triangle-alert' : 'i-lucide-clock'"
        />
        <span aria-hidden="true">{{ elapsed }}</span>
        <span class="sr-only">{{ updatedTitle }}</span>
      </span>
      <span
        v-if="source"
        class="inline-flex items-center h-5 px-1.5 rounded-full text-xs bg-s-subtle text-s-secondary"
      >
        {{ source }}
      </span>
    </div>

    <div v-if="phone" class="mt-1.5 font-mono text-[11px] text-s-muted">
      {{ phone }}
    </div>
  </div>
</template>
