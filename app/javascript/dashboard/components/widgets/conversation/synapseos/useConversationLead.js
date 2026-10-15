// CUSTOMIZAÇÃO_SYNAPSEOS — lead da conversa (GET synapseos/leads/by_conversation/:display_id).
// Estado compartilhado por conversa: o header e o painel lateral leem a mesma
// busca (sem requisição duplicada). Leads usam o display_id da conversa.
/* global axios */
import { computed, reactive, toValue, watch } from 'vue';
import { useMapGetter } from 'dashboard/composables/store';
import { resolveStatus } from 'dashboard/helper/synapseos/statusBadge';

const leadsByConversation = reactive({});

const fetchLead = async (accountId, displayId) => {
  const key = `${accountId}:${displayId}`;
  if (!leadsByConversation[key]) {
    leadsByConversation[key] = { lead: null, isFetched: false };
  }
  const entry = leadsByConversation[key];
  if (entry.isFetching) return;

  entry.isFetching = true;
  try {
    const { data } = await axios.get(
      `/api/v1/accounts/${accountId}/synapseos/leads/by_conversation/${displayId}`
    );
    entry.lead = data;
  } catch {
    // 404 = conversa ainda sem lead.
    entry.lead = null;
  } finally {
    entry.isFetching = false;
    entry.isFetched = true;
  }
};

export function useConversationLead(displayId) {
  const accountId = useMapGetter('getCurrentAccountId');
  const entry = computed(
    () => leadsByConversation[`${accountId.value}:${toValue(displayId)}`]
  );

  const refresh = () => fetchLead(accountId.value, toValue(displayId));

  watch(
    () => toValue(displayId),
    id => id && refresh(),
    { immediate: true }
  );

  const lead = computed(() => entry.value?.lead || null);
  const stage = computed(() => lead.value?.pipeline_stage || null);

  // Props do SynapseStatusBadge; etapas fora do mapa do Fykos mostram o nome.
  const stageBadge = computed(
    () =>
      stage.value && {
        status: stage.value.slug || stage.value.name,
        stageType: stage.value.stage_type,
        label: resolveStatus(stage.value.slug)?.label ? '' : stage.value.name,
      }
  );

  return {
    lead,
    stage,
    stageBadge,
    isLoading: computed(() => !entry.value?.isFetched),
    refresh,
  };
}
