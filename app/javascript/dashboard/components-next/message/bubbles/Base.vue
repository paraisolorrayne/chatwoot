<script setup>
import { computed } from 'vue';

import MessageMeta from '../MessageMeta.vue';
import ReactionsBadge from '../ReactionsBadge.vue';

import { emitter } from 'shared/helpers/mitt';
import { useMessageContext } from '../provider.js';
import { useI18n } from 'vue-i18n';

import MessageFormatter from 'shared/helpers/MessageFormatter.js';
import { BUS_EVENTS } from 'shared/constants/busEvents';
import {
  MESSAGE_STATUS,
  MESSAGE_VARIANTS,
  ORIENTATION,
  SENDER_TYPES,
} from '../constants';

const props = defineProps({
  hideMeta: { type: Boolean, default: false },
});

const {
  variant,
  orientation,
  inReplyTo,
  shouldGroupWithNext,
  isPrivate,
  sender,
  senderType,
  status,
} = useMessageContext();
const { t } = useI18n();

// CUSTOMIZAÇÃO_SYNAPSEOS — paleta s-* aplicada aos variants de bubble.
// Notas privadas emitidas por AgentBot (Otto, Luís) ganham destaque visual próprio.
const isAgentBotNote = computed(() => {
  if (!isPrivate.value) return false;
  const senderKind = sender.value?.type ?? senderType.value;
  return senderKind === SENDER_TYPES.AGENT_BOT;
});

const agentBotName = computed(() => sender.value?.name ?? '');

const aiAriaLabel = computed(() =>
  t('CONVERSATION.PRIVATE_NOTE.AI_ARIA', { agent: agentBotName.value })
);

// CUSTOMIZAÇÃO_SYNAPSEOS — paleta Fykos aplicada aos bubbles.
// Cliente = bubble-in neutro. Consultor = bubble-human (escuro no tema claro,
// claro no escuro). IA (bot/template) = brand-soft com borda ciano.
// Nota privada = warning. Activity = pill central rebaixada.
// O bubble do consultor inverte o contraste do tema, então citações e código
// do prose seguem a cor do próprio bubble.
const HUMAN_BUBBLE_NESTED =
  '[&_blockquote]:text-current [&_blockquote]:border-s-bubble-human-text/30 [&_code]:text-current [&_code]:bg-s-bubble-human-text/10 [&_pre]:bg-s-bubble-human-text/10';

const varaintBaseMap = {
  [MESSAGE_VARIANTS.AGENT]: `bg-s-bubble-human text-s-bubble-human-text ${HUMAN_BUBBLE_NESTED}`,
  [MESSAGE_VARIANTS.PRIVATE]:
    'bg-s-warning-soft text-s-warning-text border border-s-warning/30 [&_.prosemirror-mention-node]:font-semibold',
  [MESSAGE_VARIANTS.USER]: 'bg-s-bubble-in text-s-primary',
  [MESSAGE_VARIANTS.ACTIVITY]: 'bg-s-subtle text-s-muted text-xs',
  [MESSAGE_VARIANTS.BOT]:
    'bg-s-brand-soft text-s-primary border border-s-accent/30',
  [MESSAGE_VARIANTS.TEMPLATE]:
    'bg-s-brand-soft text-s-primary border border-s-accent/30',
  [MESSAGE_VARIANTS.EMAIL]: 'w-full',
  [MESSAGE_VARIANTS.UNSUPPORTED]:
    'bg-s-warning-soft/70 border border-dashed border-s-warning-text text-s-warning-text',
};

const orientationMap = {
  [ORIENTATION.LEFT]:
    'left-bubble rounded-xl ltr:rounded-bl-sm rtl:rounded-br-sm',
  [ORIENTATION.RIGHT]:
    'right-bubble rounded-xl ltr:rounded-br-sm rtl:rounded-bl-sm',
  [ORIENTATION.CENTER]: 'rounded-md',
};

const flexOrientationClass = computed(() => {
  const map = {
    [ORIENTATION.LEFT]: 'justify-start',
    [ORIENTATION.RIGHT]: 'justify-end',
    [ORIENTATION.CENTER]: 'justify-center',
  };

  return map[orientation.value];
});

const messageClass = computed(() => {
  const classToApply = [];

  if (isAgentBotNote.value) {
    // Mesmos tokens da nota humana; a borda tracejada separa a nota da IA.
    classToApply.push(
      'bg-s-warning-soft text-s-warning-text border border-dashed border-s-warning/60 [&_.prosemirror-mention-node]:font-semibold'
    );
  } else {
    classToApply.push(varaintBaseMap[variant.value]);
  }

  // CUSTOMIZAÇÃO_SYNAPSEOS — falha de envio mantém o estilo do remetente e só
  // ganha a borda de erro (o MessageError abaixo traz o aviso e o reenvio).
  if (status.value === MESSAGE_STATUS.FAILED) {
    classToApply.push('border !border-s-error');
  }

  if (variant.value !== MESSAGE_VARIANTS.ACTIVITY) {
    classToApply.push(orientationMap[orientation.value]);
  } else {
    classToApply.push('rounded-lg');
  }

  return classToApply;
});

const scrollToMessage = () => {
  emitter.emit(BUS_EVENTS.SCROLL_TO_MESSAGE, {
    messageId: inReplyTo.value.id,
  });
};

const metaColorClass = computed(() => {
  if (variant.value === MESSAGE_VARIANTS.PRIVATE) {
    return 'text-s-warning-text/80';
  }
  if (variant.value === MESSAGE_VARIANTS.AGENT) {
    return 'text-s-bubble-human-text/70';
  }
  return 'text-s-muted';
});

const replyPreviewClass = computed(() =>
  variant.value === MESSAGE_VARIANTS.AGENT
    ? 'bg-s-bubble-human-text/10'
    : 'bg-s-bubble-quote'
);

const shouldShowMeta = computed(
  () =>
    !props.hideMeta &&
    !shouldGroupWithNext.value &&
    variant.value !== MESSAGE_VARIANTS.ACTIVITY
);

const replyToPreview = computed(() => {
  if (!inReplyTo) return '';

  const { content, attachments } = inReplyTo.value;

  if (content) return new MessageFormatter(content).formattedMessage;
  if (attachments?.length) {
    const firstAttachment = attachments[0];
    const fileType = firstAttachment.fileType ?? firstAttachment.file_type;

    return t(`CHAT_LIST.ATTACHMENTS.${fileType}.CONTENT`);
  }

  return t('CONVERSATION.REPLY_MESSAGE_NOT_FOUND');
});
</script>

<template>
  <div
    :class="[
      messageClass,
      {
        'max-w-lg': variant !== MESSAGE_VARIANTS.EMAIL,
        'text-sm': variant !== MESSAGE_VARIANTS.ACTIVITY,
      },
    ]"
    :role="isAgentBotNote ? 'note' : null"
    :aria-label="isAgentBotNote ? aiAriaLabel : null"
  >
    <div
      v-if="isAgentBotNote"
      class="flex items-center justify-between gap-2 mb-2 pb-2 border-b border-dashed border-s-warning/40"
    >
      <div
        class="inline-flex items-center gap-1.5 px-2 py-0.5 rounded-full bg-s-warning/15 text-s-warning-text text-xs font-medium"
      >
        <span class="i-lucide-sparkles size-3" aria-hidden="true" />
        <span>
          {{
            $t('CONVERSATION.PRIVATE_NOTE.AI_BADGE', {
              agent: agentBotName,
            })
          }}
        </span>
      </div>
      <div
        class="inline-flex items-center gap-1 text-[11px] uppercase tracking-wide text-s-warning-text/80"
      >
        <span class="i-lucide-bot size-3" aria-hidden="true" />
        <span>{{ $t('CONVERSATION.PRIVATE_NOTE.AI_LABEL') }}</span>
      </div>
    </div>
    <div
      v-if="inReplyTo"
      role="button"
      tabindex="0"
      class="p-2 -mx-1 mb-2 rounded-lg cursor-pointer focus-visible:outline focus-visible:outline-2 focus-visible:outline-s-accent"
      :class="replyPreviewClass"
      @click="scrollToMessage"
      @keydown.enter.space.prevent="scrollToMessage"
    >
      <div
        v-dompurify-html="replyToPreview"
        class="prose prose-bubble line-clamp-2"
      />
    </div>
    <slot />
    <ReactionsBadge />
    <MessageMeta
      v-if="shouldShowMeta"
      :class="[
        flexOrientationClass,
        variant === MESSAGE_VARIANTS.EMAIL ? 'px-3 pb-3' : '',
        metaColorClass,
      ]"
      class="mt-2"
    />
  </div>
</template>
