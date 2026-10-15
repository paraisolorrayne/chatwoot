// CUSTOMIZAÇÃO_SYNAPSEOS — quem está no controle da conversa: a IA (AgentBot)
// ou um humano que respondeu há pouco. Derivado das mensagens já carregadas.
import { computed } from 'vue';
import { useNow } from '@vueuse/core';
import { useMapGetter } from 'dashboard/composables/store';
import { MESSAGE_TYPE } from 'shared/constants/messages';

// Espelha HUMAN_INTERVENTION_LOCK_MINS do gate do WF02 no n8n: a IA fica em
// silêncio por esse tempo após a última mensagem PÚBLICA de um humano.
export const HUMAN_LOCK_MINUTES = 15;

// Evento do emitter que foca o editor de resposta ("Assumir conversa").
export const FOCUS_REPLY_EDITOR = 'synapseosFocusReplyEditor';

const isPublicOutgoing = message =>
  message.message_type === MESSAGE_TYPE.OUTGOING && !message.private;

export function useBotControl() {
  const currentChat = useMapGetter('getSelectedChat');
  const currentUserId = useMapGetter('getCurrentUserID');
  // Recalcula a cada 30 s; o timer é liberado junto com o componente.
  const now = useNow({ interval: 30 * 1000 });

  const publicOutgoing = computed(() =>
    (currentChat.value?.messages || []).filter(isPublicOutgoing)
  );

  const bot = computed(
    () =>
      publicOutgoing.value.findLast(m => m.sender?.type === 'agent_bot')
        ?.sender || null
  );

  const lastHumanMessage = computed(() =>
    publicOutgoing.value.findLast(m => m.sender?.type === 'user')
  );

  const minutesLeft = computed(() => {
    if (!lastHumanMessage.value) return 0;
    const unlockAt =
      (lastHumanMessage.value.created_at + HUMAN_LOCK_MINUTES * 60) * 1000;
    return Math.min(
      HUMAN_LOCK_MINUTES,
      Math.ceil((unlockAt - now.value.getTime()) / 60000)
    );
  });

  // 'human' = humano assumiu há menos de 15 min; 'bot' = a IA respondeu por
  // último; null = sem IA nesta conversa.
  const mode = computed(() => {
    if (!bot.value) return null;
    if (minutesLeft.value > 0) return 'human';
    return publicOutgoing.value.at(-1)?.sender?.type === 'agent_bot'
      ? 'bot'
      : null;
  });

  const human = computed(() => lastHumanMessage.value?.sender || null);

  return {
    mode,
    bot,
    human,
    minutesLeft,
    isAutonomous: computed(() => mode.value === 'bot'),
    isCurrentUser: computed(() => human.value?.id === currentUserId.value),
  };
}
