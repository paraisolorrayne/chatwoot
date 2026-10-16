<script setup>
// CUSTOMIZAÇÃO_SYNAPSEOS: importa a planilha padrão. Primeiro mostra a prévia
// (o que entra, o que muda e os avisos); só grava ao confirmar.
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import VehiclesAPI from 'dashboard/api/synapseosVehicles';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import SynapseBadge from 'next/synapseos/SynapseBadge.vue';
import SynapseSkeleton from 'next/synapseos/SynapseSkeleton.vue';
import { TEMPLATE_URL } from '../knowledgeBase';

const emit = defineEmits(['imported']);

const { t } = useI18n();

const dialog = ref(null);
const fileInput = ref(null);
const file = ref(null);
const preview = ref(null);
const error = ref('');
const isPreviewing = ref(false);
const isImporting = ref(false);

const changes = computed(
  () =>
    (preview.value?.summary.created || 0) +
    (preview.value?.summary.updated || 0)
);

const STATUS_TONE = {
  created: 'success',
  updated: 'brand',
  unchanged: 'neutral',
};

const warningText = warning => {
  const key = `SYNAPSEOS.KNOWLEDGE.IMPORT_DIALOG.WARNINGS.${warning.code.toUpperCase()}`;
  return t(key, {
    line: warning.line,
    modelo: warning.modelo,
    columns: (warning.columns || []).join(', '),
    modelos: (warning.modelos || []).join(', '),
  });
};

const reset = () => {
  file.value = null;
  preview.value = null;
  error.value = '';
  if (fileInput.value) fileInput.value.value = '';
};

const open = () => {
  reset();
  dialog.value.open();
};

const onFileChange = async event => {
  const [selected] = event.target.files || [];
  if (!selected) return;
  file.value = selected;
  preview.value = null;
  error.value = '';
  isPreviewing.value = true;
  try {
    const { data } = await VehiclesAPI.importSpreadsheet(selected, false);
    preview.value = data;
  } catch (e) {
    error.value =
      e?.response?.data?.error || t('SYNAPSEOS.KNOWLEDGE.IMPORT_DIALOG.ERROR');
  } finally {
    isPreviewing.value = false;
  }
};

const confirm = async () => {
  isImporting.value = true;
  try {
    const { data } = await VehiclesAPI.importSpreadsheet(file.value, true);
    useAlert(
      t('SYNAPSEOS.KNOWLEDGE.IMPORT_DIALOG.IMPORTED', {
        count: data.summary.created + data.summary.updated,
      })
    );
    dialog.value.close();
    emit('imported');
  } catch (e) {
    error.value =
      e?.response?.data?.error || t('SYNAPSEOS.KNOWLEDGE.IMPORT_DIALOG.ERROR');
  } finally {
    isImporting.value = false;
  }
};

defineExpose({ open });
</script>

<template>
  <Dialog
    ref="dialog"
    width="2xl"
    :title="$t('SYNAPSEOS.KNOWLEDGE.IMPORT_DIALOG.TITLE')"
    :description="$t('SYNAPSEOS.KNOWLEDGE.IMPORT_DIALOG.DESCRIPTION')"
    :confirm-button-label="
      $t('SYNAPSEOS.KNOWLEDGE.IMPORT_DIALOG.CONFIRM', { count: changes })
    "
    :cancel-button-label="$t('SYNAPSEOS.KNOWLEDGE.IMPORT_DIALOG.CANCEL')"
    :is-loading="isImporting"
    :disable-confirm-button="!preview || changes === 0"
    @confirm="confirm"
    @close="reset"
  >
    <div class="flex flex-col gap-4">
      <label
        class="flex flex-col items-center justify-center gap-2 px-4 py-6 rounded-xl border border-dashed border-s-border-strong bg-s-subtle text-center cursor-pointer hover:border-s-brand has-[:focus-visible]:ring-2 has-[:focus-visible]:ring-focus"
      >
        <span
          class="i-lucide-file-spreadsheet size-6 text-s-brand-text"
          aria-hidden="true"
        />
        <span class="text-sm font-medium text-s-primary">
          {{
            file
              ? file.name
              : $t('SYNAPSEOS.KNOWLEDGE.IMPORT_DIALOG.CHOOSE_FILE')
          }}
        </span>
        <span class="text-xs text-s-muted">
          {{ $t('SYNAPSEOS.KNOWLEDGE.IMPORT_DIALOG.FILE_HINT') }}
        </span>
        <input
          ref="fileInput"
          type="file"
          accept=".xlsx,application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
          class="sr-only"
          @change="onFileChange"
        />
      </label>
      <a
        :href="TEMPLATE_URL"
        download
        class="self-start inline-flex items-center gap-1.5 text-xs text-s-brand-text hover:underline"
      >
        <span class="i-lucide-file-down size-3.5" aria-hidden="true" />
        {{ $t('SYNAPSEOS.KNOWLEDGE.DOWNLOAD_TEMPLATE') }}
      </a>

      <p v-if="error" class="text-sm text-s-error-text" role="alert">
        {{ error }}
      </p>
      <SynapseSkeleton v-else-if="isPreviewing" class="h-32 w-full" />

      <template v-else-if="preview">
        <div class="flex flex-wrap gap-2" aria-live="polite">
          <SynapseBadge tone="success">
            {{
              $t('SYNAPSEOS.KNOWLEDGE.IMPORT_DIALOG.CREATED', {
                count: preview.summary.created,
              })
            }}
          </SynapseBadge>
          <SynapseBadge tone="brand">
            {{
              $t('SYNAPSEOS.KNOWLEDGE.IMPORT_DIALOG.UPDATED', {
                count: preview.summary.updated,
              })
            }}
          </SynapseBadge>
          <SynapseBadge>
            {{
              $t('SYNAPSEOS.KNOWLEDGE.IMPORT_DIALOG.UNCHANGED', {
                count: preview.summary.unchanged,
              })
            }}
          </SynapseBadge>
        </div>

        <ul
          v-if="preview.warnings.length"
          class="reset-base flex flex-col gap-1.5 rounded-lg bg-s-warning-soft px-3 py-2 list-none"
        >
          <li
            v-for="(warning, index) in preview.warnings"
            :key="index"
            class="flex gap-2 text-xs text-s-warning-text"
          >
            <span
              class="i-lucide-triangle-alert size-3.5 mt-0.5 flex-shrink-0"
              aria-hidden="true"
            />
            {{ warningText(warning) }}
          </li>
        </ul>

        <div class="max-h-64 overflow-y-auto rounded-lg border border-s-border">
          <table class="w-full text-sm">
            <tbody>
              <tr
                v-for="row in preview.rows"
                :key="row.line"
                class="border-b last:border-b-0 border-s-border"
              >
                <td class="px-3 py-2">
                  <span class="font-medium text-s-primary">{{
                    row.modelo
                  }}</span>
                  <span v-if="row.versao" class="text-s-muted">
                    · {{ row.versao }}
                  </span>
                </td>
                <td class="px-3 py-2 text-xs text-s-muted whitespace-nowrap">
                  {{
                    $t('SYNAPSEOS.KNOWLEDGE.IMPORT_DIALOG.PHOTOS', {
                      count: row.fotos,
                    })
                  }}
                </td>
                <td class="px-3 py-2 text-right">
                  <SynapseBadge :tone="STATUS_TONE[row.status]">
                    {{
                      $t(
                        `SYNAPSEOS.KNOWLEDGE.IMPORT_DIALOG.ROW_STATUS.${row.status.toUpperCase()}`
                      )
                    }}
                  </SynapseBadge>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </template>
    </div>
  </Dialog>
</template>
