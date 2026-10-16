<script setup>
// CUSTOMIZAÇÃO_SYNAPSEOS: base de conhecimento de veículos que o agente de IA
// consulta. Formato padrão = planilha "conhecimento" (Synapseos::VehicleSchema).
import { computed, ref, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import VehiclesAPI from 'dashboard/api/synapseosVehicles';
import NextButton from 'dashboard/components-next/button/Button.vue';
import SynapseBadge from 'next/synapseos/SynapseBadge.vue';
import SynapseEmptyState from 'next/synapseos/SynapseEmptyState.vue';
import SettingsLayout from '../SettingsLayout.vue';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import VehicleEditorDrawer from './components/VehicleEditorDrawer.vue';
import VehicleImportDialog from './components/VehicleImportDialog.vue';
import { TEMPLATE_URL, formatPrice, normalizeText } from './knowledgeBase';

const { t, locale } = useI18n();

const vehicles = ref([]);
const schema = ref(null);
const isLoading = ref(true);
const search = ref('');
const editing = ref(null);
const importDialog = ref(null);

const filtered = computed(() => {
  const query = normalizeText(search.value);
  if (!query) return vehicles.value;
  return vehicles.value.filter(v =>
    normalizeText(
      [v.modelo, v.versao, v.categoria, ...(v.aliases || [])].join(' ')
    ).includes(query)
  );
});

const load = async () => {
  isLoading.value = true;
  try {
    const [list, definition] = await Promise.all([
      VehiclesAPI.get(),
      VehiclesAPI.schema(),
    ]);
    vehicles.value = list.data;
    schema.value = definition.data;
  } catch {
    useAlert(t('SYNAPSEOS.KNOWLEDGE.LOAD_ERROR'));
  } finally {
    isLoading.value = false;
  }
};

const openNew = () => {
  editing.value = { disponivel: true, specs: {}, fotos: [], aliases: [] };
};

const onSaved = vehicle => {
  const index = vehicles.value.findIndex(v => v.id === vehicle.id);
  if (index === -1) vehicles.value = [...vehicles.value, vehicle];
  else vehicles.value.splice(index, 1, vehicle);
  editing.value = null;
};

const onDeleted = id => {
  vehicles.value = vehicles.value.filter(v => v.id !== id);
  editing.value = null;
};

const completenessTone = value => {
  if (value >= 70) return 'bg-s-success';
  if (value >= 40) return 'bg-s-warning';
  return 'bg-s-error';
};

onMounted(load);
</script>

<template>
  <SettingsLayout
    :is-loading="isLoading"
    :loading-message="$t('SYNAPSEOS.KNOWLEDGE.LOADING')"
  >
    <template #header>
      <BaseSettingsHeader
        v-model:search-query="search"
        :title="$t('SYNAPSEOS.KNOWLEDGE.HEADER')"
        :description="$t('SYNAPSEOS.KNOWLEDGE.DESCRIPTION')"
        :search-placeholder="
          vehicles.length ? $t('SYNAPSEOS.KNOWLEDGE.SEARCH') : ''
        "
      >
        <template #actions>
          <a
            :href="TEMPLATE_URL"
            download
            class="inline-flex items-center gap-1.5 text-sm text-s-brand-text hover:underline"
          >
            <span class="i-lucide-file-down size-4" aria-hidden="true" />
            {{ $t('SYNAPSEOS.KNOWLEDGE.DOWNLOAD_TEMPLATE') }}
          </a>
          <NextButton
            :label="$t('SYNAPSEOS.KNOWLEDGE.IMPORT')"
            icon="i-lucide-file-up"
            color="slate"
            variant="faded"
            @click="importDialog.open()"
          />
          <NextButton
            :label="$t('SYNAPSEOS.KNOWLEDGE.NEW')"
            icon="i-lucide-plus"
            @click="openNew"
          />
        </template>
      </BaseSettingsHeader>
    </template>
    <template #body>
      <SynapseEmptyState
        v-if="!vehicles.length"
        icon="i-lucide-car-front"
        :title="$t('SYNAPSEOS.KNOWLEDGE.EMPTY_TITLE')"
        :description="$t('SYNAPSEOS.KNOWLEDGE.EMPTY_DESCRIPTION')"
        size="lg"
      />
      <p
        v-else-if="!filtered.length"
        class="py-16 text-center text-sm text-s-muted"
      >
        {{ $t('SYNAPSEOS.KNOWLEDGE.NO_RESULTS') }}
      </p>
      <div
        v-else
        class="overflow-x-auto rounded-xl border border-s-border bg-s-surface"
      >
        <table class="w-full min-w-[600px] text-sm">
          <thead>
            <tr
              class="text-left text-xs font-medium text-s-muted border-b border-s-border"
            >
              <th class="px-3 py-3 font-medium">
                {{ $t('SYNAPSEOS.KNOWLEDGE.COLUMNS.VEHICLE') }}
              </th>
              <th class="px-3 py-3 font-medium text-right">
                {{ $t('SYNAPSEOS.KNOWLEDGE.COLUMNS.PRICE') }}
              </th>
              <th class="px-3 py-3 font-medium">
                {{ $t('SYNAPSEOS.KNOWLEDGE.COLUMNS.CATEGORY') }}
              </th>
              <th class="px-3 py-3 font-medium text-right">
                {{ $t('SYNAPSEOS.KNOWLEDGE.COLUMNS.PHOTOS') }}
              </th>
              <th class="px-3 py-3 font-medium">
                <span
                  v-tooltip.top="$t('SYNAPSEOS.KNOWLEDGE.COMPLETENESS_HINT')"
                >
                  {{ $t('SYNAPSEOS.KNOWLEDGE.COLUMNS.COMPLETENESS') }}
                </span>
              </th>
            </tr>
          </thead>
          <tbody>
            <tr
              v-for="vehicle in filtered"
              :key="vehicle.id"
              class="border-b last:border-b-0 border-s-border hover:bg-s-subtle transition-colors cursor-pointer"
              @click="editing = vehicle"
            >
              <td class="px-3 py-3">
                <button
                  type="button"
                  class="reset-base flex items-center gap-3 text-left focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-focus rounded-lg"
                  @click.stop="editing = vehicle"
                >
                  <img
                    v-if="vehicle.imagem_url"
                    :src="vehicle.imagem_url"
                    alt=""
                    loading="lazy"
                    class="w-14 h-10 rounded-md object-cover bg-s-subtle flex-shrink-0"
                  />
                  <span
                    v-else
                    class="w-14 h-10 rounded-md bg-s-subtle flex items-center justify-center flex-shrink-0"
                  >
                    <span
                      class="i-lucide-car-front size-5 text-s-muted"
                      aria-hidden="true"
                    />
                  </span>
                  <span class="flex flex-col min-w-0">
                    <span class="flex items-center gap-2 min-w-0">
                      <span class="font-medium text-s-primary truncate">
                        {{ vehicle.modelo }}
                      </span>
                      <SynapseBadge v-if="!vehicle.disponivel">
                        {{ $t('SYNAPSEOS.KNOWLEDGE.STATUS.UNAVAILABLE') }}
                      </SynapseBadge>
                    </span>
                    <span
                      v-if="vehicle.versao || vehicle.ano_modelo"
                      class="text-xs text-s-muted truncate"
                    >
                      {{
                        [vehicle.versao, vehicle.ano_modelo]
                          .filter(Boolean)
                          .join(' · ')
                      }}
                    </span>
                  </span>
                </button>
              </td>
              <td
                class="px-3 py-3 text-right font-mono tabular-nums text-s-primary whitespace-nowrap"
              >
                {{ formatPrice(vehicle.preco, locale) }}
              </td>
              <td
                class="px-3 py-3 text-s-secondary max-w-[10rem] truncate"
                :title="vehicle.categoria"
              >
                {{ vehicle.categoria || '—' }}
              </td>
              <td
                class="px-3 py-3 text-right font-mono tabular-nums text-s-secondary"
              >
                {{ vehicle.fotos.length }}
              </td>
              <td class="px-3 py-3">
                <div class="flex items-center gap-2 w-24">
                  <div
                    class="h-1.5 flex-1 rounded-full bg-s-subtle overflow-hidden"
                  >
                    <div
                      class="h-full rounded-full"
                      :class="completenessTone(vehicle.completude)"
                      :style="{ width: `${vehicle.completude}%` }"
                    />
                  </div>
                  <span class="text-xs font-mono tabular-nums text-s-muted">
                    {{ vehicle.completude }}%
                  </span>
                </div>
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <VehicleEditorDrawer
        :vehicle="editing"
        :schema="schema"
        @close="editing = null"
        @saved="onSaved"
        @deleted="onDeleted"
      />
      <VehicleImportDialog ref="importDialog" @imported="load" />
    </template>
  </SettingsLayout>
</template>
