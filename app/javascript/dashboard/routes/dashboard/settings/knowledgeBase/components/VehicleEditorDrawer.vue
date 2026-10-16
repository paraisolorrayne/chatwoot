<script setup>
// CUSTOMIZAÇÃO_SYNAPSEOS: ficha de um veículo, com os campos do formato
// padrão agrupados (identificação, motor, dimensões...) e as fotos.
import { computed, nextTick, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import VehiclesAPI from 'dashboard/api/synapseosVehicles';
import SynapseButton from 'next/synapseos/SynapseButton.vue';
import SynapseInput from 'next/synapseos/SynapseInput.vue';
import ToggleSwitch from 'dashboard/components-next/switch/Switch.vue';

const props = defineProps({
  vehicle: { type: Object, default: null },
  schema: { type: Object, default: null },
});

const emit = defineEmits(['close', 'saved', 'deleted']);

const { t } = useI18n();

const form = ref(null);
const aliasesText = ref('');
const isSaving = ref(false);
const confirmingDelete = ref(false);
const panel = ref(null);
const closeButton = ref(null);
let returnFocusTo = null;
let confirmTimer = null;

const isNew = computed(() => !props.vehicle?.id);
const coreFields = computed(() => props.schema?.core_fields || []);
const isCore = key => coreFields.value.includes(key);

const groups = computed(() =>
  (props.schema?.groups || []).map(group => ({
    key: group,
    fields: props.schema.fields.filter(f => f.group === group),
  }))
);

const getValue = key =>
  isCore(key) ? form.value[key] : (form.value.specs[key] ?? '');

const setValue = (key, value) => {
  if (isCore(key)) form.value[key] = value;
  else form.value.specs[key] = value;
};

const isFilled = key => {
  const value = getValue(key);
  return value !== null && value !== undefined && value !== '';
};

const filledCount = group => group.fields.filter(f => isFilled(f.key)).length;

const fieldLabel = key => t(`SYNAPSEOS.KNOWLEDGE.FIELDS.${key}`);
const inputId = key => `vehicle-field-${key}`;

watch(
  () => props.vehicle,
  async (vehicle, previous) => {
    confirmingDelete.value = false;
    if (!vehicle) {
      form.value = null;
      returnFocusTo?.focus?.();
      returnFocusTo = null;
      return;
    }
    if (!previous) returnFocusTo = document.activeElement;
    form.value = {
      ...Object.fromEntries(coreFields.value.map(k => [k, vehicle[k] ?? ''])),
      disponivel: vehicle.disponivel ?? true,
      specs: { ...(vehicle.specs || {}) },
      fotos: (vehicle.fotos || []).map(f => ({ ...f })),
    };
    aliasesText.value = (vehicle.aliases || []).join(', ');
    await nextTick();
    closeButton.value?.focus();
  }
);

const toNumber = (value, parse) => {
  if (value === '' || value === null || value === undefined) return null;
  const number = parse(String(value).replace(',', '.'));
  return Number.isNaN(number) ? null : number;
};

const payload = () => {
  const core = Object.fromEntries(
    coreFields.value.map(k => [k, form.value[k] === '' ? null : form.value[k]])
  );
  core.versao = form.value.versao || '';
  core.ano_modelo = toNumber(form.value.ano_modelo, v => parseInt(v, 10));
  core.preco = toNumber(form.value.preco, parseFloat);
  return {
    vehicle: {
      ...core,
      aliases: aliasesText.value
        .split(',')
        .map(a => a.trim())
        .filter(Boolean),
      specs: Object.fromEntries(
        Object.entries(form.value.specs).filter(
          ([, v]) => v !== '' && v != null
        )
      ),
      fotos: form.value.fotos.filter(f => f.url),
    },
  };
};

const save = async () => {
  if (!String(form.value.modelo || '').trim()) {
    useAlert(t('SYNAPSEOS.KNOWLEDGE.EDITOR.REQUIRED_MODEL'));
    return;
  }
  isSaving.value = true;
  try {
    const { data } = isNew.value
      ? await VehiclesAPI.create(payload())
      : await VehiclesAPI.update(props.vehicle.id, payload());
    useAlert(t('SYNAPSEOS.KNOWLEDGE.EDITOR.SAVED'));
    emit('saved', data);
  } catch (error) {
    useAlert(
      error?.response?.data?.message ||
        t('SYNAPSEOS.KNOWLEDGE.EDITOR.SAVE_ERROR')
    );
  } finally {
    isSaving.value = false;
  }
};

// Exclusão em dois cliques (sem diálogo do navegador).
const remove = async () => {
  if (!confirmingDelete.value) {
    confirmingDelete.value = true;
    clearTimeout(confirmTimer);
    confirmTimer = setTimeout(() => {
      confirmingDelete.value = false;
    }, 4000);
    return;
  }
  try {
    await VehiclesAPI.delete(props.vehicle.id);
    useAlert(t('SYNAPSEOS.KNOWLEDGE.EDITOR.DELETED'));
    emit('deleted', props.vehicle.id);
  } catch {
    useAlert(t('SYNAPSEOS.KNOWLEDGE.EDITOR.SAVE_ERROR'));
  }
};

const addPhoto = () => form.value.fotos.push({ label: '', url: '' });
const removePhoto = index => form.value.fotos.splice(index, 1);

const FOCUSABLE =
  'a[href], button:not([disabled]), input, select, textarea, summary, [tabindex]:not([tabindex="-1"])';

const trapFocus = event => {
  const items = [...panel.value.querySelectorAll(FOCUSABLE)];
  const first = items[0];
  const last = items[items.length - 1];
  if (event.shiftKey && document.activeElement === first) {
    event.preventDefault();
    last.focus();
  } else if (!event.shiftKey && document.activeElement === last) {
    event.preventDefault();
    first.focus();
  }
};

const textareaClass =
  'reset-base w-full bg-s-surface border border-s-border hover:border-s-border-strong rounded-lg px-3 py-2 text-sm text-s-primary placeholder:text-s-disabled focus:outline-none focus:ring-2 focus:ring-focus focus:border-s-brand';
</script>

<template>
  <Teleport to="body">
    <div v-if="form" class="fixed inset-0 z-50 flex justify-end">
      <div
        class="absolute inset-0 bg-s-primary/20 motion-safe:animate-s-fade-in"
        aria-hidden="true"
        @click="emit('close')"
      />
      <aside
        ref="panel"
        role="dialog"
        aria-modal="true"
        aria-labelledby="vehicle-editor-title"
        class="relative flex flex-col w-full max-w-xl h-full bg-s-surface border-s border-s-border shadow-s-lg motion-safe:animate-s-slide-in-right"
        @keydown.esc="emit('close')"
        @keydown.tab="trapFocus"
      >
        <header
          class="flex items-start gap-3 px-6 pt-5 pb-4 border-b border-s-border"
        >
          <div class="flex flex-col gap-0.5 flex-1 min-w-0">
            <h2
              id="vehicle-editor-title"
              class="font-synapse-display text-lg font-semibold text-s-primary break-words"
            >
              {{
                isNew
                  ? $t('SYNAPSEOS.KNOWLEDGE.EDITOR.NEW_TITLE')
                  : vehicle.modelo
              }}
            </h2>
            <p v-if="!isNew && vehicle.versao" class="text-sm text-s-muted">
              {{ vehicle.versao }}
            </p>
          </div>
          <button
            ref="closeButton"
            type="button"
            class="reset-base p-1.5 rounded-lg text-s-muted hover:bg-s-subtle hover:text-s-primary focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-focus"
            :aria-label="$t('SYNAPSEOS.KNOWLEDGE.EDITOR.CLOSE')"
            @click="emit('close')"
          >
            <span class="i-lucide-x size-5 block" aria-hidden="true" />
          </button>
        </header>

        <div class="flex-1 overflow-y-auto px-6 py-4 flex flex-col gap-3">
          <details
            v-for="(group, index) in groups"
            :key="group.key"
            :open="index === 0"
            class="group rounded-xl border border-s-border"
          >
            <summary
              class="flex items-center justify-between gap-2 px-4 py-3 cursor-pointer list-none rounded-xl focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-focus"
            >
              <span class="text-sm font-medium text-s-primary">
                {{ $t(`SYNAPSEOS.KNOWLEDGE.GROUPS.${group.key}`) }}
              </span>
              <span class="flex items-center gap-2 text-xs text-s-muted">
                <span class="font-mono tabular-nums">
                  {{ filledCount(group) }}/{{ group.fields.length }}
                </span>
                <span
                  class="i-lucide-chevron-down size-4 transition-transform group-open:rotate-180"
                  aria-hidden="true"
                />
              </span>
            </summary>
            <div class="grid grid-cols-1 sm:grid-cols-2 gap-4 px-4 pb-4">
              <template v-for="field in group.fields" :key="field.key">
                <label
                  v-if="field.type === 'boolean'"
                  class="flex items-center justify-between gap-3 sm:col-span-2 text-sm font-medium text-s-primary"
                >
                  {{ fieldLabel(field.key) }}
                  <ToggleSwitch
                    :model-value="!!getValue(field.key)"
                    @update:model-value="setValue(field.key, $event)"
                  />
                </label>
                <div
                  v-else-if="field.type === 'text'"
                  class="flex flex-col gap-1.5 sm:col-span-2"
                >
                  <label
                    :for="inputId(field.key)"
                    class="text-sm font-medium text-s-primary"
                  >
                    {{ fieldLabel(field.key) }}
                  </label>
                  <textarea
                    :id="inputId(field.key)"
                    :value="getValue(field.key)"
                    rows="3"
                    :class="textareaClass"
                    @input="setValue(field.key, $event.target.value)"
                  />
                </div>
                <SynapseInput
                  v-else
                  :id="inputId(field.key)"
                  :label="fieldLabel(field.key)"
                  :type="
                    ['integer', 'money'].includes(field.type)
                      ? 'number'
                      : field.type === 'url'
                        ? 'url'
                        : 'text'
                  "
                  :model-value="getValue(field.key)"
                  :class="{
                    'sm:col-span-2': ['modelo', 'imagem_url'].includes(
                      field.key
                    ),
                  }"
                  @update:model-value="setValue(field.key, $event)"
                />
              </template>
              <SynapseInput
                v-if="group.key === 'identificacao'"
                id="vehicle-field-aliases"
                v-model="aliasesText"
                :label="$t('SYNAPSEOS.KNOWLEDGE.EDITOR.ALIASES')"
                :hint="$t('SYNAPSEOS.KNOWLEDGE.EDITOR.ALIASES_HINT')"
                class="sm:col-span-2"
              />
            </div>
          </details>

          <section
            class="rounded-xl border border-s-border px-4 py-3 flex flex-col gap-3"
            aria-labelledby="vehicle-photos-title"
          >
            <div class="flex items-center justify-between gap-2">
              <h3
                id="vehicle-photos-title"
                class="text-sm font-medium text-s-primary"
              >
                {{ $t('SYNAPSEOS.KNOWLEDGE.EDITOR.PHOTOS') }}
              </h3>
              <SynapseButton
                variant="ghost"
                size="sm"
                icon="i-lucide-plus"
                @click="addPhoto"
              >
                {{ $t('SYNAPSEOS.KNOWLEDGE.EDITOR.ADD_PHOTO') }}
              </SynapseButton>
            </div>
            <div
              v-for="(photo, index) in form.fotos"
              :key="index"
              class="flex items-start gap-3"
            >
              <img
                v-if="photo.url"
                :src="photo.url"
                alt=""
                loading="lazy"
                class="w-16 h-12 mt-6 rounded-md object-cover bg-s-subtle flex-shrink-0"
              />
              <span
                v-else
                class="w-16 h-12 mt-6 rounded-md bg-s-subtle flex-shrink-0"
              />
              <div class="grid grid-cols-1 sm:grid-cols-3 gap-2 flex-1 min-w-0">
                <SynapseInput
                  :id="`vehicle-photo-label-${index}`"
                  v-model="photo.label"
                  :label="$t('SYNAPSEOS.KNOWLEDGE.EDITOR.PHOTO_LABEL')"
                />
                <SynapseInput
                  :id="`vehicle-photo-url-${index}`"
                  v-model="photo.url"
                  type="url"
                  :label="$t('SYNAPSEOS.KNOWLEDGE.EDITOR.PHOTO_URL')"
                  class="sm:col-span-2"
                />
              </div>
              <button
                type="button"
                class="reset-base mt-7 p-1.5 rounded-lg text-s-muted hover:bg-s-subtle hover:text-s-error-text focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-focus"
                :aria-label="$t('SYNAPSEOS.KNOWLEDGE.EDITOR.REMOVE_PHOTO')"
                @click="removePhoto(index)"
              >
                <span
                  class="i-lucide-trash-2 size-4 block"
                  aria-hidden="true"
                />
              </button>
            </div>
          </section>
        </div>

        <footer
          class="flex items-center gap-2 px-6 py-4 border-t border-s-border"
        >
          <SynapseButton
            v-if="!isNew"
            :variant="confirmingDelete ? 'danger' : 'ghost'"
            icon="i-lucide-trash-2"
            @click="remove"
          >
            {{
              confirmingDelete
                ? $t('SYNAPSEOS.KNOWLEDGE.EDITOR.CONFIRM_DELETE')
                : $t('SYNAPSEOS.KNOWLEDGE.EDITOR.DELETE')
            }}
          </SynapseButton>
          <div class="flex-1" />
          <SynapseButton variant="outline" @click="emit('close')">
            {{ $t('SYNAPSEOS.KNOWLEDGE.EDITOR.CANCEL') }}
          </SynapseButton>
          <SynapseButton :loading="isSaving" @click="save">
            {{ $t('SYNAPSEOS.KNOWLEDGE.EDITOR.SAVE') }}
          </SynapseButton>
        </footer>
      </aside>
    </div>
  </Teleport>
</template>
