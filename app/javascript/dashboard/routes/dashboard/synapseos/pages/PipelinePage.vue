<script setup>
// CUSTOMIZAÇÃO_SYNAPSEOS — board de pipeline (design system Fykos): busca e
// filtros, cards ricos, drawer do lead, drag & drop com desfazer, confirmação ao
// encerrar (ganho/perdido) e atualização automática a cada 15 s.
import {
  computed,
  nextTick,
  onBeforeUnmount,
  onMounted,
  ref,
  watch,
} from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import { useDocumentVisibility, useIntervalFn } from '@vueuse/core';
/* global axios */
import InputText from 'primevue/inputtext';
import Select from 'primevue/select';
import Menu from 'primevue/menu';
import SynapseButton from 'next/synapseos/SynapseButton.vue';
import SynapseBadge from 'next/synapseos/SynapseBadge.vue';
import SynapseDialog from 'next/synapseos/SynapseDialog.vue';
import SynapsePageHeader from 'next/synapseos/SynapsePageHeader.vue';
import SynapseSkeleton from 'next/synapseos/SynapseSkeleton.vue';
import SynapseEmptyState from 'next/synapseos/SynapseEmptyState.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import { useAdmin } from 'dashboard/composables/useAdmin';
import PipelineColumn from '../components/pipeline/PipelineColumn.vue';
import PipelineLeadDrawer from '../components/pipeline/PipelineLeadDrawer.vue';
import PipelineToast from '../components/pipeline/PipelineToast.vue';
import PipelineColorSwatches from '../components/pipeline/PipelineColorSwatches.vue';
import {
  ATTENTION_STAGE_SLUG,
  FLASH_DURATION_MS,
  POLL_INTERVAL_MS,
  STAGE_COLOR_SWATCHES,
  TOAST_DURATION_MS,
  handlerKey,
  isClosingStage,
  isCollapsedByDefault,
  matchesSearch,
  readCollapsedState,
  sourceLabel,
  writeCollapsedState,
} from '../components/pipeline/pipelineHelpers';

const { t } = useI18n();
const route = useRoute();
const router = useRouter();
// Configuração do board (templates, estágios) só pra administradores.
const { isAdmin } = useAdmin();

const accountId = computed(() => route.params.accountId);
const apiBase = computed(() => `/api/v1/accounts/${accountId.value}/synapseos`);

const stages = ref([]);
const leads = ref([]);
const loading = ref(true);
const loaded = ref(false);
const loadError = ref(false);
const refreshing = ref(false);
const updatedAt = ref(null);

// ----- Board: carga, polling e destaque de mudanças -----------------------
// Incrementado a cada mudança local; resposta de polling iniciada antes dela é
// descartada pra não sobrescrever o movimento otimista.
let mutationSeq = 0;
const isDragging = ref(false);
const dragOverKey = ref(null);
const pendingMove = ref(null);

const flashIds = ref(new Set());
let flashTimer;

const applyBoard = data => {
  if (loaded.value) {
    const previous = new Map(leads.value.map(l => [l.id, l.pipeline_stage_id]));
    const moved = data.leads
      .filter(
        l => previous.has(l.id) && previous.get(l.id) !== l.pipeline_stage_id
      )
      .map(l => l.id);
    if (moved.length) {
      clearTimeout(flashTimer);
      flashIds.value = new Set(moved);
      flashTimer = setTimeout(() => {
        flashIds.value = new Set();
      }, FLASH_DURATION_MS);
    }
  }
  stages.value = data.stages;
  leads.value = data.leads;
};

const fetchPipeline = async ({ background = false } = {}) => {
  if (background && (refreshing.value || isDragging.value || pendingMove.value))
    return;
  const seq = mutationSeq;
  if (background) refreshing.value = true;
  else loading.value = true;
  try {
    const { data } = await axios.get(`${apiBase.value}/pipeline`);
    if (seq !== mutationSeq) return;
    applyBoard(data);
    loaded.value = true;
    loadError.value = false;
    updatedAt.value = new Date();
  } catch (e) {
    loadError.value = !loaded.value;
  } finally {
    loading.value = false;
    refreshing.value = false;
  }
};

const refresh = () => fetchPipeline({ background: true });

const visibility = useDocumentVisibility();
const { pause, resume } = useIntervalFn(refresh, POLL_INTERVAL_MS, {
  immediate: false,
});

watch(visibility, state => {
  if (state === 'visible') {
    refresh();
    resume();
  } else {
    pause();
  }
});

// ----- Busca e filtros -----------------------------------------------------
const search = ref('');
const handlerFilter = ref(null);
const sourceFilter = ref(null);
const modelFilter = ref(null);

const sortedOptions = map =>
  [...map.values()].sort((a, b) => a.label.localeCompare(b.label));

const handlerOptions = computed(() => {
  const options = new Map();
  leads.value.forEach(lead => {
    const key = handlerKey(lead);
    if (key) options.set(key, { label: lead.handler.name, value: key });
  });
  return sortedOptions(options);
});

const sourceOptions = computed(() => {
  const options = new Map();
  leads.value.forEach(lead => {
    const label = sourceLabel(t, lead.source);
    if (label) options.set(label, { label, value: label });
  });
  return sortedOptions(options);
});

const modelOptions = computed(() => {
  const options = new Map();
  leads.value.forEach(lead => {
    const model = lead.modelo_interesse;
    if (model) options.set(model, { label: model, value: model });
  });
  return sortedOptions(options);
});

const hasFilters = computed(() =>
  Boolean(
    search.value.trim() ||
      handlerFilter.value ||
      sourceFilter.value ||
      modelFilter.value
  )
);

const clearFilters = () => {
  search.value = '';
  handlerFilter.value = null;
  sourceFilter.value = null;
  modelFilter.value = null;
};

const visibleLeads = computed(() =>
  leads.value.filter(
    lead =>
      matchesSearch(lead, search.value) &&
      (!handlerFilter.value || handlerKey(lead) === handlerFilter.value) &&
      (!sourceFilter.value ||
        sourceLabel(t, lead.source) === sourceFilter.value) &&
      (!modelFilter.value || lead.modelo_interesse === modelFilter.value)
  )
);

// ----- Colunas -------------------------------------------------------------
const NO_LEADS = [];

const leadsByStage = computed(() => {
  const groups = new Map();
  visibleLeads.value.forEach(lead => {
    const key = lead.pipeline_stage_id ?? null;
    if (!groups.has(key)) groups.set(key, []);
    groups.get(key).push(lead);
  });
  return groups;
});

const leadsFor = stageId => leadsByStage.value.get(stageId) || NO_LEADS;

const stagelessStage = computed(() => ({
  id: null,
  name: t('SYNAPSEOS.PIPELINE.UNASSIGNED'),
}));

const stageById = id => stages.value.find(s => s.id === id) || null;
const stageName = id => stageById(id)?.name || stagelessStage.value.name;

const attentionStageId = computed(
  () =>
    (
      stages.value.find(s => s.slug === ATTENTION_STAGE_SLUG) ||
      stages.value.find(s => s.stage_type === 'working')
    )?.id
);

const collapsedState = ref(readCollapsedState());
const isCollapsed = stage =>
  collapsedState.value[stage.id] ?? isCollapsedByDefault(stage);
const toggleCollapse = stage => {
  collapsedState.value = {
    ...collapsedState.value,
    [stage.id]: !isCollapsed(stage),
  };
  writeCollapsedState(collapsedState.value);
};

// ----- Toast com "Desfazer" ------------------------------------------------
const toast = ref(null);
let toastTimer;

const dismissToast = () => {
  clearTimeout(toastTimer);
  toast.value = null;
};

const showToast = ({ message, tone = 'neutral', action = null }) => {
  clearTimeout(toastTimer);
  toast.value = {
    id: Date.now(),
    message,
    tone,
    actionLabel: action?.label,
    onAction: action?.handler,
  };
  toastTimer = setTimeout(dismissToast, TOAST_DURATION_MS);
};

// ----- Mover lead ----------------------------------------------------------
const findLead = id => leads.value.find(l => l.id === id);

const setLeadStage = (leadId, stageId) => {
  const lead = findLead(leadId);
  if (lead) lead.pipeline_stage_id = stageId;
  mutationSeq += 1;
};

const persistMove = async (leadId, attrs) => {
  const { data } = await axios.patch(`${apiBase.value}/leads/${leadId}`, {
    lead: attrs,
  });
  const lead = findLead(leadId);
  if (lead) Object.assign(lead, { updated_at: data.updated_at, ...attrs });
  mutationSeq += 1;
};

const showMoveError = () =>
  showToast({ message: t('SYNAPSEOS.PIPELINE.MOVE_ERROR'), tone: 'error' });

const undoMove = async ({ leadId, fromStageId, toStageId }) => {
  dismissToast();
  setLeadStage(leadId, fromStageId);
  try {
    await persistMove(leadId, { pipeline_stage_id: fromStageId });
    showToast({ message: t('SYNAPSEOS.PIPELINE.MOVE_UNDONE') });
  } catch (e) {
    setLeadStage(leadId, toStageId);
    showMoveError();
  }
};

const commitMove = async ({ leadId, fromStageId, toStageId, motivo }) => {
  try {
    await persistMove(leadId, {
      pipeline_stage_id: toStageId,
      ...(motivo ? { motivo } : {}),
    });
    // Ganho/perdido encerram o negócio no backend: desfazer só reverteria o card.
    const undoable = !isClosingStage(stageById(toStageId));
    showToast({
      message: t('SYNAPSEOS.PIPELINE.MOVED_TO', {
        stage: stageName(toStageId),
      }),
      action: undoable
        ? {
            label: t('SYNAPSEOS.PIPELINE.UNDO'),
            handler: () => undoMove({ leadId, fromStageId, toStageId }),
          }
        : null,
    });
  } catch (e) {
    setLeadStage(leadId, fromStageId);
    showMoveError();
  }
};

// Ganho/perdido pedem confirmação; perdido pede também o motivo.
const closingDialog = ref(null);
const lossReasons = ref(null);
const lossReason = ref('');

const pendingIsLost = computed(
  () => pendingMove.value?.stage.stage_type === 'lost'
);
const closingConfirmDisabled = computed(
  () =>
    pendingIsLost.value &&
    (lossReasons.value === null ||
      (lossReasons.value.length > 0 && !lossReason.value))
);

const ensureLossReasons = async () => {
  if (lossReasons.value) return;
  try {
    const { data } = await axios.get(
      `${apiBase.value}/pipeline_stages/loss_reasons`
    );
    lossReasons.value = data.loss_reasons || [];
  } catch (e) {
    lossReasons.value = [];
  }
};

const requestMove = (lead, toStageId) => {
  const fromStageId = lead.pipeline_stage_id ?? null;
  if (fromStageId === toStageId) return;
  setLeadStage(lead.id, toStageId);
  const stage = stageById(toStageId);
  if (!isClosingStage(stage)) {
    commitMove({ leadId: lead.id, fromStageId, toStageId });
    return;
  }
  lossReason.value = '';
  pendingMove.value = {
    leadId: lead.id,
    leadName: lead.contact?.name,
    fromStageId,
    toStageId,
    stage,
  };
  closingDialog.value.open();
  if (stage.stage_type === 'lost') ensureLossReasons();
};

const confirmClosingMove = () => {
  const move = pendingMove.value;
  const motivo = pendingIsLost.value ? lossReason.value : '';
  pendingMove.value = null;
  closingDialog.value.close();
  commitMove({ ...move, motivo });
};

const cancelClosingMove = () => {
  if (!pendingMove.value) return;
  setLeadStage(pendingMove.value.leadId, pendingMove.value.fromStageId);
  pendingMove.value = null;
};

const onDragChange = (event, stageId) => {
  if (event.added) requestMove(event.added.element, stageId);
};

const onDragMove = evt => {
  dragOverKey.value = evt.to?.dataset?.stageKey ?? null;
};

const onDragEnd = () => {
  isDragging.value = false;
  dragOverKey.value = null;
};

const isDropTarget = stageId =>
  isDragging.value && dragOverKey.value === String(stageId ?? 'none');

// Alternativa ao arraste pelo teclado: menu "Mover para…" de cada card.
const moveMenu = ref(null);
const moveMenuLead = ref(null);
const moveMenuOpen = ref(false);

const moveFromMenu = async (lead, stageId) => {
  requestMove(lead, stageId);
  if (pendingMove.value) return;
  await nextTick();
  document.querySelector(`[data-lead-id="${lead.id}"]`)?.focus();
};

const moveMenuItems = computed(() => {
  const lead = moveMenuLead.value;
  if (!lead) return [];
  return [
    {
      label: t('SYNAPSEOS.PIPELINE.MOVE_TO'),
      items: stages.value
        .filter(stage => stage.id !== lead.pipeline_stage_id)
        .map(stage => ({
          label: stage.name,
          command: () => moveFromMenu(lead, stage.id),
        })),
    },
  ];
});

const toggleMoveMenu = async (event, lead) => {
  const target = event.currentTarget;
  const reopen = !(moveMenuOpen.value && moveMenuLead.value?.id === lead.id);
  moveMenu.value.hide();
  if (!reopen) return;
  moveMenuLead.value = lead;
  await nextTick();
  moveMenu.value.show(event, target);
};

// ----- Drawer do lead ------------------------------------------------------
const selectedLeadId = ref(null);
const selectedLead = computed(() => findLead(selectedLeadId.value) || null);
const selectedStage = computed(
  () => selectedLead.value && stageById(selectedLead.value.pipeline_stage_id)
);

const openConversation = lead => {
  // rota do Chatwoot usa display_id; conversation_id é o id interno e abriria
  // a conversa errada (bug display×interno).
  router.push({
    name: 'inbox_conversation',
    params: {
      accountId: accountId.value,
      conversation_id: lead.conversation_display_id,
    },
  });
};

// ----- Configuração (admin) ------------------------------------------------
const configMenu = ref(null);
const showNewStageDialog = ref(false);
const newStageName = ref('');
const newStageColor = ref(STAGE_COLOR_SWATCHES[0].hex);
const newStageType = ref('custom');

const stageTypeOptions = [
  { label: t('SYNAPSEOS.PIPELINE.STAGE_TYPES.INBOUND'), value: 'inbound' },
  { label: t('SYNAPSEOS.PIPELINE.STAGE_TYPES.WORKING'), value: 'working' },
  { label: t('SYNAPSEOS.PIPELINE.STAGE_TYPES.WON'), value: 'won' },
  { label: t('SYNAPSEOS.PIPELINE.STAGE_TYPES.LOST'), value: 'lost' },
  { label: t('SYNAPSEOS.PIPELINE.STAGE_TYPES.CUSTOM'), value: 'custom' },
];

const openNewStage = () => {
  newStageName.value = '';
  newStageColor.value = STAGE_COLOR_SWATCHES[0].hex;
  newStageType.value = 'custom';
  showNewStageDialog.value = true;
};

const submitNewStage = async () => {
  if (!newStageName.value.trim()) return;
  const { data } = await axios.post(`${apiBase.value}/pipeline_stages`, {
    pipeline_stage: {
      name: newStageName.value.trim(),
      color: newStageColor.value,
      stage_type: newStageType.value,
    },
  });
  stages.value.push(data);
  showNewStageDialog.value = false;
};

const renameStage = async (stage, name) => {
  const { data } = await axios.patch(
    `${apiBase.value}/pipeline_stages/${stage.id}`,
    { pipeline_stage: { name } }
  );
  Object.assign(stage, data);
};

const deleteDialog = ref(null);
const stageToDelete = ref(null);

const askDeleteStage = stage => {
  stageToDelete.value = stage;
  deleteDialog.value.open();
};

const confirmDeleteStage = async () => {
  const stage = stageToDelete.value;
  deleteDialog.value.close();
  await axios.delete(`${apiBase.value}/pipeline_stages/${stage.id}`);
  stages.value = stages.value.filter(s => s.id !== stage.id);
  leads.value.forEach(l => {
    if (l.pipeline_stage_id === stage.id) l.pipeline_stage_id = null;
  });
  mutationSeq += 1;
};

const showTemplateDialog = ref(false);
const templates = ref([]);
const templatesError = ref(null);
const templatesEmpty = ref(false);
const loadingTemplates = ref(false);
const applyingTemplate = ref(false);
const templateDialog = ref(null);
const templateToApply = ref(null);
// De-para da troca de template: { [id do estágio atual]: slug no template }.
const templatePreview = ref(null);
const templateMapping = ref({});
const templatePreviewError = ref(null);
const leadsToMove = computed(() =>
  (templatePreview.value?.current_stages || []).reduce(
    (sum, s) => sum + s.leads_count,
    0
  )
);

const openTemplates = async () => {
  showTemplateDialog.value = true;
  loadingTemplates.value = true;
  templatesError.value = null;
  templatesEmpty.value = false;
  try {
    const { data } = await axios.get(
      `${apiBase.value}/pipeline_stages/templates`
    );
    templates.value = Array.isArray(data) ? data : [];
    templatesEmpty.value = templates.value.length === 0;
  } catch (e) {
    templates.value = [];
    templatesError.value =
      e?.response?.data?.error ||
      e?.message ||
      t('SYNAPSEOS.PIPELINE.TEMPLATE_FETCH_ERROR');
  } finally {
    loadingTemplates.value = false;
  }
};

const askApplyTemplate = async tmpl => {
  templateToApply.value = tmpl;
  templatePreview.value = null;
  templatePreviewError.value = null;
  showTemplateDialog.value = false;
  templateDialog.value.open();
  try {
    const { data } = await axios.get(
      `${apiBase.value}/pipeline_stages/template_preview`,
      { params: { template_key: tmpl.key } }
    );
    templatePreview.value = data;
    templateMapping.value = Object.fromEntries(
      data.current_stages.map(s => [s.id, s.suggested_slug])
    );
  } catch {
    templatePreviewError.value = t('SYNAPSEOS.PIPELINE.TEMPLATE_MAP_ERROR');
  }
};

const applyTemplate = async () => {
  applyingTemplate.value = true;
  try {
    await axios.post(`${apiBase.value}/pipeline_stages/apply_template`, {
      template_key: templateToApply.value.key,
      mapping: templateMapping.value,
    });
    templateDialog.value.close();
    await fetchPipeline();
  } finally {
    applyingTemplate.value = false;
  }
};

const configMenuItems = computed(() => [
  {
    label: t('SYNAPSEOS.PIPELINE.TEMPLATES'),
    icon: 'i-lucide-layout-template size-4',
    command: openTemplates,
  },
  {
    label: t('SYNAPSEOS.PIPELINE.ADD_STAGE'),
    icon: 'i-lucide-plus size-4',
    command: openNewStage,
  },
]);

onMounted(async () => {
  await fetchPipeline();
  if (visibility.value === 'visible') resume();
});

onBeforeUnmount(() => {
  clearTimeout(toastTimer);
  clearTimeout(flashTimer);
});
</script>

<template>
  <div
    class="bg-s-bg p-4 sm:p-6 h-full w-full flex-1 min-w-0 flex flex-col gap-4 overflow-hidden"
  >
    <SynapsePageHeader
      :title="t('SYNAPSEOS.PIPELINE.TITLE')"
      :description="t('SYNAPSEOS.PIPELINE.SUBTITLE')"
      :updated-at="updatedAt"
      :refreshing="refreshing"
    >
      <template #actions>
        <SynapseButton
          variant="outline"
          size="sm"
          icon="i-lucide-refresh-cw"
          :aria-label="t('SYNAPSEOS.PIPELINE.REFRESH')"
          :title="t('SYNAPSEOS.PIPELINE.REFRESH')"
          :disabled="refreshing || !loaded"
          @click="refresh"
        />
        <template v-if="isAdmin">
          <SynapseButton
            variant="ghost"
            size="sm"
            icon="i-lucide-settings-2"
            icon-trailing="i-lucide-chevron-down"
            aria-haspopup="menu"
            @click="configMenu.toggle($event)"
          >
            {{ t('SYNAPSEOS.PIPELINE.CONFIGURE') }}
          </SynapseButton>
          <Menu ref="configMenu" :model="configMenuItems" popup />
        </template>
      </template>
    </SynapsePageHeader>

    <div
      v-if="loaded && stages.length && leads.length"
      class="flex flex-wrap items-center gap-2"
    >
      <div class="relative w-full sm:w-72">
        <span
          class="i-lucide-search absolute start-3 top-1/2 -translate-y-1/2 size-4 text-s-muted pointer-events-none"
        />
        <input
          v-model="search"
          type="search"
          :placeholder="t('SYNAPSEOS.PIPELINE.SEARCH_PLACEHOLDER')"
          :aria-label="t('SYNAPSEOS.PIPELINE.SEARCH_PLACEHOLDER')"
          class="reset-base w-full h-9 ps-9 pe-3 rounded-lg border border-s-border bg-s-surface text-sm text-s-primary placeholder:text-s-disabled hover:border-s-border-strong focus:outline-none focus:ring-2 focus:ring-focus focus:border-s-brand"
        />
      </div>
      <Select
        v-model="handlerFilter"
        :options="handlerOptions"
        option-label="label"
        option-value="value"
        show-clear
        size="small"
        :placeholder="t('SYNAPSEOS.PIPELINE.FILTERS.HANDLER')"
        :aria-label="t('SYNAPSEOS.PIPELINE.FILTERS.HANDLER')"
        class="w-full sm:w-44"
      />
      <Select
        v-model="sourceFilter"
        :options="sourceOptions"
        option-label="label"
        option-value="value"
        show-clear
        size="small"
        :placeholder="t('SYNAPSEOS.PIPELINE.FILTERS.SOURCE')"
        :aria-label="t('SYNAPSEOS.PIPELINE.FILTERS.SOURCE')"
        class="w-full sm:w-40"
      />
      <Select
        v-model="modelFilter"
        :options="modelOptions"
        option-label="label"
        option-value="value"
        show-clear
        filter
        size="small"
        :placeholder="t('SYNAPSEOS.PIPELINE.FILTERS.MODEL')"
        :aria-label="t('SYNAPSEOS.PIPELINE.FILTERS.MODEL')"
        class="w-full sm:w-44"
      />
      <template v-if="hasFilters">
        <SynapseButton
          variant="ghost"
          size="sm"
          icon="i-lucide-filter-x"
          @click="clearFilters"
        >
          {{ t('SYNAPSEOS.PIPELINE.CLEAR_FILTERS') }}
        </SynapseButton>
        <span class="text-xs text-s-muted tabular-nums" aria-live="polite">
          {{
            t('SYNAPSEOS.PIPELINE.FILTERED_COUNT', {
              count: visibleLeads.length,
            })
          }}
        </span>
      </template>
    </div>

    <div
      v-if="!loaded && loading"
      class="flex gap-3 flex-1 min-h-0 overflow-hidden"
      aria-busy="true"
      :aria-label="t('SYNAPSEOS.PIPELINE.LOADING')"
    >
      <div
        v-for="n in 4"
        :key="n"
        class="flex flex-col gap-2 w-64 shrink-0 p-3 rounded-2xl border border-s-border bg-s-subtle"
      >
        <SynapseSkeleton class="h-5 w-32" />
        <SynapseSkeleton v-for="card in 3" :key="card" class="h-24 w-full" />
      </div>
    </div>

    <SynapseEmptyState
      v-else-if="loadError"
      icon="i-lucide-circle-alert"
      size="lg"
      :title="t('SYNAPSEOS.PIPELINE.LOAD_ERROR')"
    >
      <SynapseButton variant="outline" size="sm" @click="fetchPipeline()">
        {{ t('SYNAPSEOS.PIPELINE.RETRY') }}
      </SynapseButton>
    </SynapseEmptyState>

    <SynapseEmptyState
      v-else-if="!stages.length"
      icon="i-lucide-kanban"
      size="lg"
      :title="t('SYNAPSEOS.PIPELINE.EMPTY_STAGES_TITLE')"
      :description="t('SYNAPSEOS.PIPELINE.EMPTY_STAGES_DESCRIPTION')"
    >
      <SynapseButton
        v-if="isAdmin"
        variant="primary"
        size="sm"
        icon="i-lucide-layout-template"
        @click="openTemplates"
      >
        {{ t('SYNAPSEOS.PIPELINE.TEMPLATES') }}
      </SynapseButton>
    </SynapseEmptyState>

    <template v-else>
      <SynapseEmptyState
        v-if="!leads.length"
        icon="i-lucide-kanban"
        size="sm"
        :title="t('SYNAPSEOS.PIPELINE.EMPTY_LEADS_TITLE')"
        :description="t('SYNAPSEOS.PIPELINE.EMPTY_LEADS_DESCRIPTION')"
      />
      <div class="flex gap-3 overflow-x-auto flex-1 min-h-0 pb-2">
        <PipelineColumn
          v-if="leadsFor(null).length"
          :stage="stagelessStage"
          :leads="leadsFor(null)"
          :collapsible="false"
          :drop-target="isDropTarget(null)"
          :flash-ids="flashIds"
          :move="onDragMove"
          @change="e => onDragChange(e, null)"
          @start="isDragging = true"
          @end="onDragEnd"
          @open-lead="lead => (selectedLeadId = lead.id)"
          @move-menu="toggleMoveMenu"
        />
        <PipelineColumn
          v-for="stage in stages"
          :key="stage.id"
          :stage="stage"
          :leads="leadsFor(stage.id)"
          :collapsed="isCollapsed(stage)"
          :attention="stage.id === attentionStageId"
          :drop-target="isDropTarget(stage.id)"
          :editable="isAdmin"
          :flash-ids="flashIds"
          :move="onDragMove"
          @toggle-collapse="toggleCollapse(stage)"
          @change="e => onDragChange(e, stage.id)"
          @start="isDragging = true"
          @end="onDragEnd"
          @open-lead="lead => (selectedLeadId = lead.id)"
          @move-menu="toggleMoveMenu"
          @rename="name => renameStage(stage, name)"
          @delete="askDeleteStage(stage)"
        />
      </div>
    </template>

    <Menu
      ref="moveMenu"
      :model="moveMenuItems"
      popup
      @show="moveMenuOpen = true"
      @hide="moveMenuOpen = false"
    />

    <PipelineLeadDrawer
      :lead="selectedLead"
      :stage="selectedStage"
      @close="selectedLeadId = null"
      @open-conversation="openConversation(selectedLead)"
    />

    <PipelineToast
      :toast="toast"
      @action="toast?.onAction?.()"
      @dismiss="dismissToast"
    />

    <!-- Confirmação ao soltar em ganho/perdido -->
    <Dialog
      ref="closingDialog"
      :type="pendingIsLost ? 'alert' : 'edit'"
      width="md"
      :title="
        pendingIsLost
          ? t('SYNAPSEOS.PIPELINE.CONFIRM_LOST_TITLE')
          : t('SYNAPSEOS.PIPELINE.CONFIRM_WON_TITLE')
      "
      :description="
        pendingMove
          ? t('SYNAPSEOS.PIPELINE.CONFIRM_CLOSE_DESCRIPTION', {
              name: pendingMove.leadName,
              stage: pendingMove.stage.name,
            })
          : ''
      "
      :confirm-button-label="t('SYNAPSEOS.PIPELINE.CONFIRM')"
      :cancel-button-label="t('SYNAPSEOS.PIPELINE.CANCEL')"
      :disable-confirm-button="closingConfirmDisabled"
      @confirm="confirmClosingMove"
      @close="cancelClosingMove"
    >
      <fieldset v-if="pendingIsLost" class="flex flex-col gap-2">
        <legend class="mb-2 text-sm font-medium text-s-primary">
          {{ t('SYNAPSEOS.PIPELINE.LOSS_REASON') }}
        </legend>
        <SynapseSkeleton v-if="lossReasons === null" class="h-10 w-full" />
        <label
          v-for="reason in lossReasons"
          :key="reason"
          class="flex items-center gap-2 px-3 py-2 rounded-lg border border-s-border bg-s-surface text-sm font-normal text-s-primary cursor-pointer has-[:checked]:border-s-accent has-[:checked]:bg-s-brand-soft has-[:focus-visible]:ring-2 has-[:focus-visible]:ring-focus"
        >
          <input
            v-model="lossReason"
            type="radio"
            name="pipeline-loss-reason"
            :value="reason"
            class="accent-s-accent"
          />
          {{ reason }}
        </label>
      </fieldset>
    </Dialog>

    <Dialog
      ref="deleteDialog"
      type="alert"
      width="md"
      :title="t('SYNAPSEOS.PIPELINE.DELETE_STAGE_TITLE')"
      :description="
        stageToDelete
          ? t('SYNAPSEOS.PIPELINE.CONFIRM_DELETE', { name: stageToDelete.name })
          : ''
      "
      :confirm-button-label="t('SYNAPSEOS.PIPELINE.DELETE')"
      :cancel-button-label="t('SYNAPSEOS.PIPELINE.CANCEL')"
      @confirm="confirmDeleteStage"
    />

    <Dialog
      ref="templateDialog"
      width="xl"
      :title="
        t('SYNAPSEOS.PIPELINE.TEMPLATE_CONFIRM_TITLE', {
          name: templateToApply?.name,
        })
      "
      :description="t('SYNAPSEOS.PIPELINE.TEMPLATE_CONFIRM')"
      :confirm-button-label="t('SYNAPSEOS.PIPELINE.TEMPLATE_APPLY_AND_MOVE')"
      :cancel-button-label="t('SYNAPSEOS.PIPELINE.CANCEL')"
      :is-loading="applyingTemplate"
      :disable-confirm-button="!templatePreview"
      @confirm="applyTemplate"
    >
      <p v-if="templatePreviewError" class="text-sm text-s-error-text">
        {{ templatePreviewError }}
      </p>
      <SynapseSkeleton v-else-if="!templatePreview" class="h-32 w-full" />
      <p
        v-else-if="!templatePreview.current_stages.length"
        class="text-sm text-s-secondary"
      >
        {{ t('SYNAPSEOS.PIPELINE.TEMPLATE_MAP_EMPTY') }}
      </p>
      <div v-else class="flex flex-col gap-3">
        <table class="w-full text-sm">
          <thead>
            <tr class="text-left text-xs text-s-muted">
              <th class="pb-2 font-medium">
                {{ t('SYNAPSEOS.PIPELINE.TEMPLATE_MAP_FROM') }}
              </th>
              <th class="pb-2 font-medium text-right">
                {{ t('SYNAPSEOS.PIPELINE.TEMPLATE_MAP_LEADS') }}
              </th>
              <th class="pb-2 ps-4 font-medium">
                {{ t('SYNAPSEOS.PIPELINE.TEMPLATE_MAP_TO') }}
              </th>
            </tr>
          </thead>
          <tbody>
            <tr
              v-for="stage in templatePreview.current_stages"
              :key="stage.id"
              class="border-t border-s-border"
            >
              <td class="py-2">
                <span class="inline-flex items-center gap-2 text-s-primary">
                  <span
                    class="size-2 rounded-full flex-shrink-0"
                    :style="{ backgroundColor: stage.color }"
                  />
                  {{ stage.name }}
                </span>
              </td>
              <td
                class="py-2 text-right font-mono tabular-nums text-s-secondary"
              >
                {{ stage.leads_count }}
              </td>
              <td class="py-2 ps-4">
                <Select
                  v-model="templateMapping[stage.id]"
                  :options="templatePreview.target_stages"
                  option-label="name"
                  option-value="slug"
                  :aria-label="`${t('SYNAPSEOS.PIPELINE.TEMPLATE_MAP_TO')}: ${stage.name}`"
                  class="w-full"
                />
              </td>
            </tr>
          </tbody>
        </table>
        <p class="text-xs text-s-secondary">
          {{
            t('SYNAPSEOS.PIPELINE.TEMPLATE_MAP_SUMMARY', {
              count: leadsToMove,
            })
          }}
        </p>
      </div>
    </Dialog>

    <!-- New Stage Dialog -->
    <SynapseDialog
      v-model:visible="showNewStageDialog"
      :header="t('SYNAPSEOS.PIPELINE.NEW_STAGE_HEADER')"
      modal
      class="w-[420px]"
    >
      <div class="flex flex-col gap-4">
        <label class="text-sm text-s-primary">
          {{ t('SYNAPSEOS.PIPELINE.STAGE_NAME') }}
          <InputText v-model="newStageName" class="w-full mt-1" />
        </label>
        <PipelineColorSwatches v-model="newStageColor" />
        <label class="text-sm text-s-primary">
          {{ t('SYNAPSEOS.PIPELINE.STAGE_TYPE') }}
          <Select
            v-model="newStageType"
            :options="stageTypeOptions"
            option-label="label"
            option-value="value"
            class="w-full mt-1"
          />
        </label>
        <span class="text-xs text-s-muted">
          {{ t('SYNAPSEOS.PIPELINE.STAGE_TYPE_HINT') }}
        </span>
      </div>
      <template #footer>
        <div class="flex justify-end gap-2">
          <SynapseButton variant="ghost" @click="showNewStageDialog = false">
            {{ t('SYNAPSEOS.PIPELINE.CANCEL') }}
          </SynapseButton>
          <SynapseButton
            variant="primary"
            :disabled="!newStageName.trim()"
            @click="submitNewStage"
          >
            {{ t('SYNAPSEOS.PIPELINE.CREATE') }}
          </SynapseButton>
        </div>
      </template>
    </SynapseDialog>

    <!-- Template Picker Dialog -->
    <SynapseDialog
      v-model:visible="showTemplateDialog"
      :header="t('SYNAPSEOS.PIPELINE.TEMPLATE_HEADER')"
      modal
      class="w-[560px]"
    >
      <div v-if="loadingTemplates" class="flex flex-col gap-3">
        <SynapseSkeleton v-for="n in 3" :key="n" class="h-16 w-full" />
      </div>
      <div v-else class="flex flex-col gap-3">
        <span class="text-sm text-s-muted">
          {{ t('SYNAPSEOS.PIPELINE.TEMPLATE_DESCRIPTION') }}
        </span>
        <div
          v-if="templatesError"
          class="rounded-md border border-s-error/30 bg-s-error-soft text-s-error-text text-xs p-3"
        >
          {{ templatesError }}
        </div>
        <div
          v-else-if="templatesEmpty"
          class="text-sm text-s-muted text-center py-4"
        >
          {{ t('SYNAPSEOS.PIPELINE.TEMPLATE_EMPTY') }}
        </div>
        <button
          v-for="tmpl in templates"
          :key="tmpl.key"
          type="button"
          class="block w-full p-4 text-start border border-s-border rounded-xl hover:border-s-accent transition-colors focus:outline-none focus-visible:ring-2 focus-visible:ring-focus"
          @click="askApplyTemplate(tmpl)"
        >
          <span class="flex items-center justify-between gap-2">
            <span class="text-sm font-semibold text-s-primary">
              {{ tmpl.name }}
            </span>
            <SynapseBadge tone="neutral">
              {{
                t('SYNAPSEOS.PIPELINE.TEMPLATE_STAGES', {
                  count: tmpl.stage_count,
                })
              }}
            </SynapseBadge>
          </span>
          <span class="block text-xs font-normal text-s-muted mt-1">
            {{ tmpl.description }}
          </span>
        </button>
      </div>
      <template #footer>
        <div class="flex justify-end">
          <SynapseButton variant="ghost" @click="showTemplateDialog = false">
            {{ t('SYNAPSEOS.PIPELINE.CANCEL') }}
          </SynapseButton>
        </div>
      </template>
    </SynapseDialog>
  </div>
</template>
