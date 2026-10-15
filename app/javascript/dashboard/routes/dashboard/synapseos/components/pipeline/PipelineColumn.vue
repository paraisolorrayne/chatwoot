<script setup>
// CUSTOMIZAÇÃO_SYNAPSEOS — coluna do board (Fykos). Expandida: cabeçalho com
// nome, contagem e total; recolhida: faixa vertical que continua aceitando drop.
import { computed, nextTick, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import draggable from 'vuedraggable';
import InputText from 'primevue/inputtext';
import SynapseBadge from 'next/synapseos/SynapseBadge.vue';
import PipelineLeadCard from './PipelineLeadCard.vue';
import { formatBRL } from './pipelineHelpers';

const props = defineProps({
  stage: { type: Object, required: true },
  leads: { type: Array, required: true },
  collapsed: { type: Boolean, default: false },
  collapsible: { type: Boolean, default: true },
  attention: { type: Boolean, default: false },
  dropTarget: { type: Boolean, default: false },
  editable: { type: Boolean, default: false },
  flashIds: { type: Set, required: true },
  move: { type: Function, required: true },
});

const emit = defineEmits([
  'toggleCollapse',
  'change',
  'start',
  'end',
  'openLead',
  'moveMenu',
  'rename',
  'delete',
]);

const { t } = useI18n();

const stageKey = computed(() => String(props.stage.id ?? 'none'));
const dotStyle = computed(() =>
  props.stage.color ? { backgroundColor: props.stage.color } : null
);
const total = computed(() => {
  const sum = props.leads.reduce((acc, l) => acc + (l.deal?.amount || 0), 0);
  return sum
    ? t('SYNAPSEOS.PIPELINE.STAGE_SUM', { value: formatBRL(sum) })
    : '';
});

const editing = ref(false);
const draftName = ref('');
const nameInput = ref(null);

const startEdit = async () => {
  draftName.value = props.stage.name;
  editing.value = true;
  await nextTick();
  nameInput.value?.$el?.focus();
};

const commitEdit = () => {
  if (!editing.value) return;
  editing.value = false;
  const name = draftName.value.trim();
  if (name && name !== props.stage.name) emit('rename', name);
};

const sortableOptions = {
  group: 'leads',
  itemKey: 'id',
  animation: 150,
  delay: 150,
  delayOnTouchOnly: true,
  ghostClass: 'pipeline-ghost',
  chosenClass: 'pipeline-chosen',
  filter: 'button',
  preventOnFilter: false,
};
</script>

<template>
  <draggable
    v-if="collapsed"
    :model-value="[]"
    v-bind="sortableOptions"
    :move="move"
    :data-stage-key="stageKey"
    class="flex flex-col items-center w-12 shrink-0 h-full rounded-2xl border bg-s-subtle transition-colors duration-150 [&>.pipeline-ghost]:!h-1 [&>.pipeline-ghost]:!w-8 [&>.pipeline-ghost]:!p-0 [&>.pipeline-ghost]:!mb-3 [&>.pipeline-ghost]:!border-0 [&>.pipeline-ghost]:!bg-s-accent [&>.pipeline-ghost]:overflow-hidden"
    :class="[
      attention ? 'border-s-warning/40' : 'border-s-border',
      dropTarget ? 'ring-2 ring-s-accent/60 bg-s-brand-soft' : '',
    ]"
    @change="e => emit('change', e)"
    @start="emit('start')"
    @end="emit('end')"
  >
    <template #header>
      <button
        type="button"
        class="flex flex-col items-center gap-2 w-full flex-1 min-h-0 py-3 rounded-2xl hover:bg-s-hover focus:outline-none focus-visible:ring-2 focus-visible:ring-focus"
        :aria-label="
          t('SYNAPSEOS.PIPELINE.EXPAND_COLUMN', { name: stage.name })
        "
        aria-expanded="false"
        @click="emit('toggleCollapse')"
      >
        <span class="i-lucide-chevrons-left-right size-4 text-s-muted" />
        <span
          class="size-2 rounded-full shrink-0"
          :class="{ 'bg-s-muted': !dotStyle }"
          :style="dotStyle"
        />
        <SynapseBadge tone="neutral">{{ leads.length }}</SynapseBadge>
        <span
          class="text-sm font-semibold text-s-primary whitespace-nowrap [writing-mode:vertical-rl]"
        >
          {{ stage.name }}
        </span>
      </button>
    </template>
    <template #item>
      <span />
    </template>
  </draggable>

  <section
    v-else
    class="flex flex-col w-64 shrink-0 h-full rounded-2xl border bg-s-subtle transition-colors duration-150"
    :class="[
      attention ? 'border-s-warning/40' : 'border-s-border',
      dropTarget ? 'ring-2 ring-s-accent/60 bg-s-brand-soft' : '',
    ]"
    :aria-label="stage.name"
  >
    <header
      class="group/header px-3 pt-3 pb-2 border-b border-s-border-subtle rounded-t-2xl"
      :class="{ 'bg-s-warning-soft': attention }"
    >
      <div class="flex items-start gap-2">
        <span
          class="mt-1.5 size-2 rounded-full shrink-0"
          :class="{ 'bg-s-muted': !dotStyle }"
          :style="dotStyle"
        />
        <InputText
          v-if="editing"
          ref="nameInput"
          v-model="draftName"
          size="small"
          class="reset-base !text-sm flex-1 min-w-0"
          :aria-label="t('SYNAPSEOS.PIPELINE.STAGE_NAME')"
          @blur="commitEdit"
          @keydown.enter="commitEdit"
          @keydown.escape="editing = false"
        />
        <button
          v-else-if="editable"
          type="button"
          class="flex-1 min-w-0 p-0 text-start text-sm font-semibold leading-snug text-s-primary line-clamp-2 break-words rounded cursor-text focus:outline-none focus-visible:ring-2 focus-visible:ring-focus"
          :title="t('SYNAPSEOS.PIPELINE.RENAME_STAGE')"
          @click="startEdit"
        >
          {{ stage.name }}
        </button>
        <h2
          v-else
          class="flex-1 min-w-0 text-sm font-semibold leading-snug text-s-primary line-clamp-2 break-words"
        >
          {{ stage.name }}
        </h2>
        <span
          v-if="stage.description"
          v-tooltip.top="stage.description"
          tabindex="0"
          role="img"
          :aria-label="stage.description"
          class="i-lucide-help-circle mt-0.5 size-4 shrink-0 text-s-muted cursor-help rounded-full focus:outline-none focus-visible:ring-2 focus-visible:ring-focus"
        />
        <SynapseBadge tone="neutral" class="tabular-nums">
          {{ leads.length }}
        </SynapseBadge>
        <button
          v-if="editable"
          type="button"
          class="shrink-0 -m-0.5 p-0.5 rounded-md text-s-muted opacity-0 transition-opacity hover:text-s-error-text group-hover/header:opacity-100 focus:outline-none focus-visible:opacity-100 focus-visible:ring-2 focus-visible:ring-focus"
          :aria-label="
            t('SYNAPSEOS.PIPELINE.DELETE_STAGE', { name: stage.name })
          "
          @click="emit('delete')"
        >
          <span class="i-lucide-trash-2 block size-4" />
        </button>
        <button
          v-if="collapsible"
          type="button"
          class="shrink-0 -m-0.5 p-0.5 rounded-md text-s-muted hover:text-s-primary hover:bg-s-hover focus:outline-none focus-visible:ring-2 focus-visible:ring-focus"
          :aria-label="
            t('SYNAPSEOS.PIPELINE.COLLAPSE_COLUMN', { name: stage.name })
          "
          aria-expanded="true"
          @click="emit('toggleCollapse')"
        >
          <span class="i-lucide-chevrons-right-left block size-4" />
        </button>
      </div>
      <div
        v-if="total"
        class="mt-1 ps-4 text-xs font-medium text-s-success-text tabular-nums"
      >
        {{ total }}
      </div>
    </header>

    <draggable
      :model-value="leads"
      v-bind="sortableOptions"
      :move="move"
      :data-stage-key="stageKey"
      role="list"
      :aria-label="stage.name"
      class="flex flex-col gap-2 p-2 overflow-y-auto flex-1 min-h-24"
      @change="e => emit('change', e)"
      @start="emit('start')"
      @end="emit('end')"
    >
      <template #item="{ element }">
        <PipelineLeadCard
          :lead="element"
          :stage="stage.id ? stage : null"
          :flashing="flashIds.has(element.id)"
          @open="emit('openLead', element)"
          @move-menu="e => emit('moveMenu', e, element)"
        />
      </template>
      <template #footer>
        <div v-if="!leads.length" class="py-6 text-center text-xs text-s-muted">
          {{ t('SYNAPSEOS.PIPELINE.EMPTY_COLUMN') }}
        </div>
      </template>
    </draggable>
  </section>
</template>
