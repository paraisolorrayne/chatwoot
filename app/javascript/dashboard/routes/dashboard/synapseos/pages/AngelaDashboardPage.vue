<script setup>
// Painel da Ângela (Tier 1) — Patrimônio da base instalada.
// Regra de fábrica (ADR-002): blocos de ESTOQUE (patrimônio/ciclo/resultados/
// memória/forecast/grafo) são all-time e NÃO reagem ao filtro de período — são
// buscados uma vez. O bloco OPERACIONAL é fluxo e refaz a busca quando o período
// muda. Patrimônio no topo, operacional no rodapé.
//
// Consome o proxy Rails -> attra-py (read-API), montado no PR do proxy.
import { ref, computed, onMounted } from 'vue';
import { useRoute } from 'vue-router';
/* global axios */
import SynapseCard from 'next/synapseos/SynapseCard.vue';
import SynapseKpiCard from 'next/synapseos/SynapseKpiCard.vue';

const route = useRoute();
const base = computed(
  () => `/api/v1/accounts/${route.params.accountId}/synapseos/angela/dashboard`
);

// --- ESTOQUE (all-time; busca única) ---
const patrimonio = ref(null);
const ciclo = ref(null);
const resultados = ref(null);
const memoria = ref(null);
const forecast = ref(null);
const grafo = ref(null);
const loadingEstoque = ref(true);

// --- FLUXO (operacional; reage ao período) ---
const periodOptions = [
  { label: '7d', value: 7 },
  { label: '30d', value: 30 },
  { label: '90d', value: 90 },
];
const period = ref(30);
const operacional = ref(null);
const loadingFluxo = ref(true);

const fmtNum = v => new Intl.NumberFormat('pt-BR').format(v || 0);
const fmtBRL = v =>
  new Intl.NumberFormat('pt-BR', { style: 'currency', currency: 'BRL' }).format(
    v || 0
  );
const fmtPct = v => `${((v || 0) * 100).toFixed(1)}%`;

const get = async (section, params) =>
  (await axios.get(`${base.value}/${section}`, { params })).data;

const fetchEstoque = async () => {
  loadingEstoque.value = true;
  try {
    const [p, c, r, m, f, g] = await Promise.all([
      get('patrimonio'),
      get('ciclo'),
      get('resultados'),
      get('memoria'),
      get('forecast'),
      get('grafo'),
    ]);
    patrimonio.value = p;
    ciclo.value = c;
    resultados.value = r;
    memoria.value = m;
    forecast.value = f;
    grafo.value = g;
  } finally {
    loadingEstoque.value = false;
  }
};

const isoDaysAgo = n => {
  const d = new Date();
  d.setDate(d.getDate() - n);
  return d.toISOString().slice(0, 10);
};
const fetchOperacional = async () => {
  loadingFluxo.value = true;
  try {
    operacional.value = await get('operacional', {
      desde: isoDaysAgo(period.value),
      ate: isoDaysAgo(0),
    });
  } finally {
    loadingFluxo.value = false;
  }
};
const setPeriod = v => {
  period.value = v;
  fetchOperacional();
};

const grafoTotais = computed(() => grafo.value?.totais || {});

onMounted(() => {
  fetchEstoque();
  fetchOperacional();
});
</script>

<template>
  <div class="flex flex-col gap-6 p-6">
    <header>
      <h1 class="text-xl font-semibold">Painel da Ângela — Patrimônio da Base</h1>
      <p class="text-sm opacity-70">
        Relacionamento e pós-venda · o que prende vem primeiro.
      </p>
    </header>

    <!-- 1) PATRIMÔNIO (topo, all-time, não-filtrável) -->
    <section class="grid grid-cols-1 gap-4 sm:grid-cols-3">
      <SynapseKpiCard
        label="Clientes sob acompanhamento"
        :value="fmtNum(patrimonio?.clientes_sob_acompanhamento)"
        tone="brand"
      />
      <SynapseKpiCard
        label="Receita prevista (proxy última compra)"
        :value="fmtBRL(forecast?.receita_prevista_total_brl)"
        tone="success"
      />
      <SynapseKpiCard
        label="Relacionamentos no grafo"
        :value="fmtNum(grafoTotais.clientes)"
        tone="neutral"
      />
    </section>

    <!-- 2) CICLO DE TROCA POR FASE (estoque) -->
    <SynapseCard title="Ciclo de troca por fase" subtitle="Distribuição da base (all-time)">
      <ul class="flex flex-col gap-2">
        <li
          v-for="f in ciclo?.fases || []"
          :key="f.fase"
          class="flex justify-between"
        >
          <span>{{ f.fase }}</span>
          <strong>{{ fmtNum(f.clientes) }}</strong>
        </li>
      </ul>
      <p class="mt-2 text-sm opacity-70">
        Total distinto: {{ fmtNum(ciclo?.total) }}
      </p>
    </SynapseCard>

    <!-- 3) VOZ DO CLIENTE (placeholder até LLM ligar) -->
    <SynapseCard title="Voz do Cliente" subtitle="Motivo de troca / satisfação">
      <p class="text-sm opacity-70">
        Em breve — depende do enriquecimento por LLM (hoje desligado).
      </p>
    </SynapseCard>

    <!-- 4) MEMÓRIA & RELACIONAMENTO (estoque) -->
    <SynapseCard
      title="Memória & Relacionamento"
      subtitle="O fosso que sobrevive ao turnover (all-time)"
    >
      <div class="grid grid-cols-2 gap-4 sm:grid-cols-4">
        <SynapseKpiCard
          label="Dias de acompanhamento"
          :value="fmtNum(memoria?.dias_acompanhamento_base)"
          tone="neutral"
        />
        <SynapseKpiCard
          label="Interações registradas"
          :value="fmtNum(memoria?.interacoes_registradas)"
          tone="neutral"
        />
        <SynapseKpiCard
          label="Profundidade média/cliente"
          :value="fmtNum(memoria?.profundidade_media_por_cliente)"
          tone="neutral"
        />
        <SynapseKpiCard
          label="Relacionamentos sob cuidado"
          :value="fmtNum(memoria?.relacionamentos_sob_cuidado)"
          tone="brand"
        />
      </div>
    </SynapseCard>

    <!-- 5) RESULTADOS (sem cobrar vendedor; estoque) -->
    <SynapseCard title="Resultados" subtitle="O que a Ângela fez pelo cliente (all-time)">
      <div class="grid grid-cols-2 gap-4">
        <SynapseKpiCard
          label="Clientes engajados"
          :value="fmtNum(resultados?.clientes_engajados)"
          tone="success"
        />
        <SynapseKpiCard
          label="Sinais de troca gerados"
          :value="fmtNum(resultados?.sinais_troca_gerados)"
          tone="brand"
        />
      </div>
    </SynapseCard>

    <!-- 6) OPERACIONAL (rodapé, FLUXO — reage ao período) -->
    <SynapseCard title="Operacional" subtitle="Atividade da Ângela no período (fluxo)">
      <template #actions>
        <div class="flex gap-1">
          <button
            v-for="o in periodOptions"
            :key="o.value"
            class="rounded px-2 py-1 text-xs"
            :class="period === o.value ? 'font-bold underline' : 'opacity-60'"
            @click="setPeriod(o.value)"
          >
            {{ o.label }}
          </button>
        </div>
      </template>
      <div class="grid grid-cols-2 gap-4 sm:grid-cols-3">
        <SynapseKpiCard
          label="Mensagens enviadas"
          :value="fmtNum(operacional?.mensagens_enviadas)"
          tone="neutral"
        />
        <SynapseKpiCard
          label="Mensagens recebidas"
          :value="fmtNum(operacional?.mensagens_recebidas)"
          tone="neutral"
        />
        <SynapseKpiCard
          label="Taxa de resposta"
          :value="fmtPct(operacional?.taxa_resposta)"
          tone="success"
        />
        <SynapseKpiCard
          label="Follow-ups agendados"
          :value="fmtNum(operacional?.followups_agendados)"
          tone="neutral"
        />
        <SynapseKpiCard
          label="Escaladas ao humano"
          :value="fmtNum(operacional?.escaladas_humano)"
          tone="warning"
        />
        <SynapseKpiCard
          label="Opt-out (compliance)"
          :value="fmtNum(operacional?.opted_out_total)"
          tone="neutral"
        />
      </div>
    </SynapseCard>
  </div>
</template>
