<script setup>
/* global axios */
// CUSTOMIZAÇÃO_SYNAPSEOS: Inteligência nativa. Os dados vêm do data lake do
// painel agentic (conversas analisadas pela IA) via
// GET synapseos/intelligence/:section; cada seção carrega e falha sozinha.
import { computed, onMounted, reactive } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute } from 'vue-router';
import SynapsePageHeader from 'next/synapseos/SynapsePageHeader.vue';
import SynapseKpiCard from 'next/synapseos/SynapseKpiCard.vue';
import IntelligenceSection from '../components/intelligence/IntelligenceSection.vue';
import IntelligenceBarList from '../components/intelligence/IntelligenceBarList.vue';
import { useDashboardFormat } from '../components/dashboard/useDashboardFormat';

const { t, te } = useI18n();
const route = useRoute();
const { formatNumber, formatPercent, formatCurrency } = useDashboardFormat();

const SECTIONS = [
  'forecast',
  'demanda',
  'pipeline-receita',
  'voz-cliente',
  'overview',
];
const state = reactive(
  Object.fromEntries(
    SECTIONS.map(s => [s, { data: null, loading: true, error: '' }])
  )
);

const load = async section => {
  const entry = state[section];
  entry.loading = true;
  entry.error = '';
  try {
    const { data } = await axios.get(
      `/api/v1/accounts/${route.params.accountId}/synapseos/intelligence/${section}`
    );
    entry.data = data;
  } catch {
    entry.error = t('SYNAPSEOS.INTELLIGENCE.ERROR');
  } finally {
    entry.loading = false;
  }
};

const UNKNOWN = ['(n/d)', '(sem modelo)', '(sem origem)', 'sem_horizonte'];

// Rótulo traduzido para os códigos do data lake ("preco", "1-3m"...).
const labelFor = (group, raw) => {
  if (UNKNOWN.includes(raw) && raw !== 'sem_horizonte') {
    return t('SYNAPSEOS.INTELLIGENCE.UNKNOWN');
  }
  const code = String(raw)
    .replace('+', 'mais_')
    .replace(/[^a-z0-9_]/gi, '_');
  const key = `SYNAPSEOS.INTELLIGENCE.LABELS.${group}.${code}`;
  if (te(key)) return t(key);
  return String(raw).replace(/_/g, ' ');
};

const countItems = (list, group) =>
  (list || []).map(item => ({
    key: item.label,
    label: labelFor(group, item.label),
    value: item.count,
  }));

const money = value => formatCurrency(value, { compact: true });

const forecast = computed(() => state.forecast.data);
const forecastByHorizon = computed(() =>
  (forecast.value?.by_horizonte || []).map(item => ({
    key: item.horizonte,
    label: labelFor('HORIZONTE', item.horizonte),
    value: item.count,
    detail: item.receita ? money(item.receita) : '',
  }))
);
const forecastByModel = computed(() =>
  (forecast.value?.by_modelo || []).map(item => ({
    key: item.modelo,
    label: UNKNOWN.includes(item.modelo)
      ? t('SYNAPSEOS.INTELLIGENCE.UNKNOWN')
      : item.modelo,
    value: item.count,
    detail: item.receita ? money(item.receita) : '',
  }))
);

const demand = computed(() =>
  (state.demanda.data?.by_modelo || []).map(item => ({
    key: item.modelo,
    label: UNKNOWN.includes(item.modelo)
      ? t('SYNAPSEOS.INTELLIGENCE.UNKNOWN')
      : item.modelo,
    value: item.count,
    detail: item.receita_potencial ? money(item.receita_potencial) : '',
  }))
);

const stages = computed(() =>
  (state['pipeline-receita'].data?.by_estagio || []).map(item => ({
    key: item.estagio,
    label: labelFor('ESTAGIO', item.estagio),
    value: item.count,
    detail: item.receita_potencial ? money(item.receita_potencial) : '',
  }))
);

const voice = computed(() => state['voz-cliente'].data);
const SENTIMENT_BARS = {
  positivo: 'bg-s-success',
  neutro: 'bg-s-chart-3',
  negativo: 'bg-s-error',
};
const sentiment = computed(() => {
  const list = (voice.value?.sentimento || []).filter(
    s => SENTIMENT_BARS[s.label]
  );
  const total = list.reduce((sum, s) => sum + s.count, 0) || 1;
  return list.map(s => ({
    key: s.label,
    label: labelFor('SENTIMENTO', s.label),
    share: (s.count / total) * 100,
    bar: SENTIMENT_BARS[s.label],
  }));
});

const overview = computed(() => state.overview.data);
const funnel = computed(() => {
  const f = overview.value?.funnel;
  if (!f) return [];
  return ['total', 'contatados', 'responderam', 'com_ia', 'bloqueados'].map(
    step => ({
      key: step,
      label: t(`SYNAPSEOS.INTELLIGENCE.ACQUISITION.FUNNEL_STEPS.${step}`),
      value: f[step],
      detail:
        step === 'total' || !f.total
          ? ''
          : formatPercent((f[step] / f.total) * 100),
    })
  );
});
const sends = computed(() => {
  const e = overview.value?.envios;
  if (!e) return [];
  return [
    'disparos_periodo',
    'followups_periodo',
    'disparos_hoje',
    'followups_hoje',
    'backlog',
  ].map(key => ({
    key,
    label: t(`SYNAPSEOS.INTELLIGENCE.ACQUISITION.SENDS_ITEMS.${key}`),
    value: e[key],
  }));
});

onMounted(() => SECTIONS.forEach(load));
</script>

<template>
  <div class="bg-s-bg h-full w-full flex-1 min-w-0 overflow-auto">
    <div class="p-4 md:p-6 flex flex-col gap-4 md:gap-6">
      <SynapsePageHeader
        :title="t('SYNAPSEOS.INTELLIGENCE.TITLE')"
        :description="t('SYNAPSEOS.INTELLIGENCE.SUBTITLE')"
      />

      <IntelligenceSection
        :title="t('SYNAPSEOS.INTELLIGENCE.FORECAST.TITLE')"
        :description="t('SYNAPSEOS.INTELLIGENCE.FORECAST.DESCRIPTION')"
        :loading="state.forecast.loading"
        :error="state.forecast.error"
        :retry-label="t('SYNAPSEOS.INTELLIGENCE.RETRY')"
        @retry="load('forecast')"
      >
        <div class="grid grid-cols-1 sm:grid-cols-3 gap-3">
          <SynapseKpiCard
            :label="t('SYNAPSEOS.INTELLIGENCE.FORECAST.REVENUE')"
            :value="formatCurrency(forecast?.receita_total || 0)"
            icon="i-lucide-trending-up"
            tone="success"
          />
          <SynapseKpiCard
            :label="t('SYNAPSEOS.INTELLIGENCE.FORECAST.LEADS')"
            :value="formatNumber(forecast?.total || 0)"
            icon="i-lucide-calendar-clock"
          />
          <SynapseKpiCard
            :label="t('SYNAPSEOS.INTELLIGENCE.FORECAST.NO_MODEL')"
            :value="formatNumber(forecast?.sem_modelo || 0)"
            icon="i-lucide-circle-help"
            tone="neutral"
          />
        </div>
        <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
          <div class="flex flex-col gap-3">
            <h3 class="text-sm font-medium text-s-secondary">
              {{ t('SYNAPSEOS.INTELLIGENCE.FORECAST.BY_HORIZON') }}
            </h3>
            <IntelligenceBarList
              :items="forecastByHorizon"
              :format="formatNumber"
              bar="bg-s-chart-6"
              :empty-text="t('SYNAPSEOS.INTELLIGENCE.EMPTY')"
            />
          </div>
          <div class="flex flex-col gap-3">
            <h3 class="text-sm font-medium text-s-secondary">
              {{ t('SYNAPSEOS.INTELLIGENCE.FORECAST.BY_MODEL') }}
            </h3>
            <IntelligenceBarList
              :items="forecastByModel"
              :format="formatNumber"
              bar="bg-s-chart-6"
              :empty-text="t('SYNAPSEOS.INTELLIGENCE.EMPTY')"
            />
          </div>
        </div>
      </IntelligenceSection>

      <div class="grid grid-cols-1 xl:grid-cols-2 gap-4 md:gap-6">
        <IntelligenceSection
          :title="t('SYNAPSEOS.INTELLIGENCE.DEMAND.TITLE')"
          :description="
            state.demanda.data
              ? t('SYNAPSEOS.INTELLIGENCE.DEMAND.DESCRIPTION', {
                  value: formatCurrency(state.demanda.data.receita_total || 0),
                })
              : ''
          "
          :loading="state.demanda.loading"
          :error="state.demanda.error"
          :retry-label="t('SYNAPSEOS.INTELLIGENCE.RETRY')"
          @retry="load('demanda')"
        >
          <IntelligenceBarList
            :items="demand"
            :format="formatNumber"
            :empty-text="t('SYNAPSEOS.INTELLIGENCE.EMPTY')"
          />
        </IntelligenceSection>

        <IntelligenceSection
          :title="t('SYNAPSEOS.INTELLIGENCE.STAGE.TITLE')"
          :description="t('SYNAPSEOS.INTELLIGENCE.STAGE.DESCRIPTION')"
          :loading="state['pipeline-receita'].loading"
          :error="state['pipeline-receita'].error"
          :retry-label="t('SYNAPSEOS.INTELLIGENCE.RETRY')"
          @retry="load('pipeline-receita')"
        >
          <IntelligenceBarList
            :items="stages"
            :format="formatNumber"
            bar="bg-s-chart-2"
            :empty-text="t('SYNAPSEOS.INTELLIGENCE.EMPTY')"
          />
        </IntelligenceSection>
      </div>

      <IntelligenceSection
        :title="t('SYNAPSEOS.INTELLIGENCE.VOICE.TITLE')"
        :description="
          voice
            ? t('SYNAPSEOS.INTELLIGENCE.VOICE.DESCRIPTION', {
                total: formatNumber(voice.total || 0),
              })
            : ''
        "
        :loading="state['voz-cliente'].loading"
        :error="state['voz-cliente'].error"
        :retry-label="t('SYNAPSEOS.INTELLIGENCE.RETRY')"
        @retry="load('voz-cliente')"
      >
        <div v-if="sentiment.length" class="flex flex-col gap-2">
          <h3 class="text-sm font-medium text-s-secondary">
            {{ t('SYNAPSEOS.INTELLIGENCE.VOICE.SENTIMENT') }}
          </h3>
          <div class="flex h-2.5 rounded-full overflow-hidden bg-s-subtle">
            <div
              v-for="item in sentiment"
              :key="item.key"
              :class="item.bar"
              :style="{ width: `${item.share}%` }"
            />
          </div>
          <ul
            class="reset-base list-none flex flex-wrap gap-x-4 gap-y-1 text-xs"
          >
            <li
              v-for="item in sentiment"
              :key="item.key"
              class="flex items-center gap-1.5 text-s-secondary"
            >
              <span class="size-2 rounded-full" :class="item.bar" />
              {{ item.label }}
              <span class="font-mono tabular-nums text-s-muted">
                {{ formatPercent(item.share) }}
              </span>
            </li>
          </ul>
        </div>
        <div class="grid grid-cols-1 md:grid-cols-3 gap-6">
          <div
            v-for="block in [
              { key: 'OBJECOES', list: voice?.objecoes, bar: 'bg-s-chart-4' },
              { key: 'INTENCOES', list: voice?.intencoes, bar: 'bg-s-chart-1' },
              { key: 'USO', list: voice?.uso, bar: 'bg-s-chart-7' },
            ]"
            :key="block.key"
            class="flex flex-col gap-3"
          >
            <h3 class="text-sm font-medium text-s-secondary">
              {{ t(`SYNAPSEOS.INTELLIGENCE.VOICE.${block.key}`) }}
            </h3>
            <IntelligenceBarList
              :items="countItems(block.list, block.key)"
              :format="formatNumber"
              :bar="block.bar"
              :limit="6"
              :empty-text="t('SYNAPSEOS.INTELLIGENCE.EMPTY')"
            />
          </div>
        </div>
      </IntelligenceSection>

      <IntelligenceSection
        :title="t('SYNAPSEOS.INTELLIGENCE.ACQUISITION.TITLE')"
        :description="t('SYNAPSEOS.INTELLIGENCE.ACQUISITION.DESCRIPTION')"
        :loading="state.overview.loading"
        :error="state.overview.error"
        :retry-label="t('SYNAPSEOS.INTELLIGENCE.RETRY')"
        @retry="load('overview')"
      >
        <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
          <div class="flex flex-col gap-3">
            <h3 class="text-sm font-medium text-s-secondary">
              {{ t('SYNAPSEOS.INTELLIGENCE.ACQUISITION.FUNNEL') }}
            </h3>
            <IntelligenceBarList
              :items="funnel"
              :format="formatNumber"
              bar="bg-s-chart-1"
              :empty-text="t('SYNAPSEOS.INTELLIGENCE.EMPTY')"
            />
          </div>
          <div class="flex flex-col gap-3">
            <h3 class="text-sm font-medium text-s-secondary">
              {{ t('SYNAPSEOS.INTELLIGENCE.ACQUISITION.SENDS') }}
            </h3>
            <dl class="grid grid-cols-2 gap-3">
              <div
                v-for="item in sends"
                :key="item.key"
                class="rounded-lg bg-s-subtle px-3 py-2"
              >
                <dt class="text-xs text-s-muted">{{ item.label }}</dt>
                <dd
                  class="font-synapse-display text-lg font-semibold tabular-nums text-s-primary"
                >
                  {{ formatNumber(item.value) }}
                </dd>
              </div>
            </dl>
          </div>
        </div>
        <div
          v-if="overview?.by_origem?.length"
          class="flex flex-col gap-3 min-w-0"
        >
          <h3 class="text-sm font-medium text-s-secondary">
            {{ t('SYNAPSEOS.INTELLIGENCE.ACQUISITION.BY_SOURCE') }}
          </h3>
          <div class="overflow-x-auto rounded-lg border border-s-border">
            <table class="w-full min-w-[480px] text-sm">
              <thead>
                <tr
                  class="text-left text-xs text-s-muted border-b border-s-border"
                >
                  <th class="px-3 py-2 font-medium">
                    {{ t('SYNAPSEOS.INTELLIGENCE.ACQUISITION.COL_SOURCE') }}
                  </th>
                  <th class="px-3 py-2 font-medium text-right">
                    {{ t('SYNAPSEOS.INTELLIGENCE.ACQUISITION.COL_TOTAL') }}
                  </th>
                  <th class="px-3 py-2 font-medium text-right">
                    {{ t('SYNAPSEOS.INTELLIGENCE.ACQUISITION.COL_REPLIED') }}
                  </th>
                  <th class="px-3 py-2 font-medium text-right">
                    {{ t('SYNAPSEOS.INTELLIGENCE.ACQUISITION.COL_RATE') }}
                  </th>
                </tr>
              </thead>
              <tbody>
                <tr
                  v-for="row in overview.by_origem"
                  :key="row.origem"
                  class="border-b last:border-b-0 border-s-border"
                >
                  <td class="px-3 py-2 text-s-primary">
                    {{
                      UNKNOWN.includes(row.origem)
                        ? t('SYNAPSEOS.INTELLIGENCE.UNKNOWN')
                        : row.origem
                    }}
                  </td>
                  <td
                    class="px-3 py-2 text-right font-mono tabular-nums text-s-secondary"
                  >
                    {{ formatNumber(row.total) }}
                  </td>
                  <td
                    class="px-3 py-2 text-right font-mono tabular-nums text-s-secondary"
                  >
                    {{ formatNumber(row.responderam) }}
                  </td>
                  <td
                    class="px-3 py-2 text-right font-mono tabular-nums text-s-primary"
                  >
                    {{ formatPercent(row.taxa_resposta) }}
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </IntelligenceSection>
    </div>
  </div>
</template>
