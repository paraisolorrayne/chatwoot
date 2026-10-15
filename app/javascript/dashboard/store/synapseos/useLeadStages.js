// CUSTOMIZAÇÃO_SYNAPSEOS — estágio do lead de cada conversa da lista, por
// display_id: chip do card e filtro local da aba "Precisa de você".
// Pede em lote só o que falta e pede de novo quando a conversa teve atividade
// depois do último pedido (a IA muda o estágio junto com uma mensagem).
import { defineStore } from 'pinia';
import LeadStagesAPI from 'dashboard/api/synapseos/leadStages';

// display_id -> last_activity_at do último pedido (não vai pro state: não é exibido)
const requestedAt = new Map();

export const useLeadStagesStore = defineStore('synapseosLeadStages', {
  // display_id -> { id, slug, name, stage_type, needs_human } | null (sem lead/estágio)
  state: () => ({ stages: {} }),

  getters: {
    stageFor: state => id => state.stages[id],
    // undefined enquanto não sabemos: a aba mantém a conversa até a resposta chegar
    needsHuman: state => id =>
      id in state.stages ? Boolean(state.stages[id]?.needs_human) : undefined,
  },

  actions: {
    async ensure(conversations) {
      const stale = conversations.filter(
        ({ id, last_activity_at: at }) => (requestedAt.get(id) ?? -1) < at
      );
      if (!stale.length) return;

      stale.forEach(({ id, last_activity_at: at }) => requestedAt.set(id, at));
      try {
        const { data } = await LeadStagesAPI.get(stale.map(({ id }) => id));
        Object.assign(this.stages, data);
      } catch {
        // sem chip; tenta de novo na próxima atividade da conversa
      }
    },

    reset() {
      requestedAt.clear();
      this.stages = {};
    },
  },
});
