<script setup>
import { computed, ref } from 'vue';
import { useRoute } from 'vue-router';
import { useStore } from 'vuex';
import { useElementSize } from '@vueuse/core';
import BackButton from '../BackButton.vue';
import InboxName from '../InboxName.vue';
import MoreActions from './MoreActions.vue';
import SidepanelSwitch from 'dashboard/components-next/Conversation/SidepanelSwitch.vue';
import Avatar from 'next/avatar/Avatar.vue';
import SLACardLabel from './components/SLACardLabel.vue';
import wootConstants from 'dashboard/constants/globals';
import { conversationListPageURL } from 'dashboard/helper/URLHelper';
import { snoozedReopenTime } from 'dashboard/helper/snoozeHelpers';
import { useInbox } from 'dashboard/composables/useInbox';
import { useI18n } from 'vue-i18n';
// CUSTOMIZAÇÃO_SYNAPSEOS: chip de controle IA/humano, etapa do lead e "Assumir conversa".
import Button from 'dashboard/components-next/button/Button.vue';
import SynapseStatusBadge from 'next/synapseos/SynapseStatusBadge.vue';
import { emitter } from 'shared/helpers/mitt';
import { agentClasses } from 'dashboard/helper/synapseos/agentIdentity';
import { useBotControl, FOCUS_REPLY_EDITOR } from './synapseos/useBotControl';
import { useConversationLead } from './synapseos/useConversationLead';

const props = defineProps({
  chat: {
    type: Object,
    default: () => ({}),
  },
  showBackButton: {
    type: Boolean,
    default: false,
  },
});

const { t } = useI18n();
const store = useStore();
const route = useRoute();
const conversationHeader = ref(null);
const { width } = useElementSize(conversationHeader);
const { isAWebWidgetInbox } = useInbox();

const currentChat = computed(() => store.getters.getSelectedChat);
const accountId = computed(() => store.getters.getCurrentAccountId);

const chatMetadata = computed(() => props.chat.meta);

const backButtonUrl = computed(() => {
  const {
    params: { inbox_id: inboxId, label, teamId, id: customViewId },
    name,
  } = route;

  const conversationTypeMap = {
    conversation_through_mentions: 'mention',
    conversation_through_participating: 'participating',
    conversation_through_unattended: 'unattended',
  };
  return conversationListPageURL({
    accountId: accountId.value,
    inboxId,
    label,
    teamId,
    conversationType: conversationTypeMap[name],
    customViewId,
  });
});

const isHMACVerified = computed(() => {
  if (!isAWebWidgetInbox.value) {
    return true;
  }
  return chatMetadata.value.hmac_verified;
});

const currentContact = computed(() =>
  store.getters['contacts/getContact'](props.chat.meta.sender.id)
);

const isSnoozed = computed(
  () => currentChat.value.status === wootConstants.STATUS_TYPE.SNOOZED
);

const snoozedDisplayText = computed(() => {
  const { snoozed_until: snoozedUntil } = currentChat.value;
  if (snoozedUntil) {
    return `${t('CONVERSATION.HEADER.SNOOZED_UNTIL')} ${snoozedReopenTime(snoozedUntil)}`;
  }
  return t('CONVERSATION.HEADER.SNOOZED_UNTIL_NEXT_REPLY');
});

const inbox = computed(() => {
  const { inbox_id: inboxId } = props.chat;
  return store.getters['inboxes/getInbox'](inboxId);
});

const hasMultipleInboxes = computed(
  () => store.getters['inboxes/getInboxes'].length > 1
);

const hasSlaPolicyId = computed(() => props.chat?.sla_policy_id);

// CUSTOMIZAÇÃO_SYNAPSEOS
const { mode, bot, human, minutesLeft, isAutonomous, isCurrentUser } =
  useBotControl();
const { stageBadge } = useConversationLead(() => props.chat.id);

const botDotClass = computed(() => agentClasses({ name: bot.value?.name }).bg);

const controlLabel = computed(() => {
  const params = { bot: bot.value?.name, minutes: minutesLeft.value };
  if (mode.value === 'bot') {
    return t('SYNAPSEOS.CONVERSATION.CONTROL.AUTONOMOUS', params);
  }
  if (isCurrentUser.value) {
    return t('SYNAPSEOS.CONVERSATION.CONTROL.YOU_TOOK_OVER', params);
  }
  return t('SYNAPSEOS.CONVERSATION.CONTROL.HUMAN_TOOK_OVER', {
    ...params,
    name: human.value?.available_name || human.value?.name,
  });
});

// Só foca o editor: é o envio da mensagem que pausa a IA (gate do n8n).
const takeOver = () => emitter.emit(FOCUS_REPLY_EDITOR);
</script>

<template>
  <div
    ref="conversationHeader"
    class="flex flex-col gap-3 items-center justify-between flex-1 w-full min-w-0 xl:flex-row px-3 sm:px-4 pt-3 pb-2 h-24 xl:h-14 bg-s-surface border-b border-s-border"
  >
    <div
      class="flex items-center justify-start w-full xl:w-auto max-w-full min-w-0 xl:flex-1"
    >
      <BackButton
        v-if="showBackButton"
        :back-url="backButtonUrl"
        class="ltr:mr-2 rtl:ml-2"
      />
      <Avatar
        :name="currentContact.name"
        :src="currentContact.thumbnail"
        :size="32"
        :status="currentContact.availability_status"
        hide-offline-status
        rounded-full
      />
      <div
        class="flex flex-col items-start min-w-0 ml-2 overflow-hidden rtl:ml-0 rtl:mr-2"
      >
        <div class="flex flex-row items-center max-w-full gap-1 p-0 m-0">
          <span
            class="min-w-0 text-sm sm:text-[15px] font-semibold truncate leading-tight text-s-primary"
          >
            {{ currentContact.name }}
          </span>
          <fluent-icon
            v-if="!isHMACVerified"
            v-tooltip="$t('CONVERSATION.UNVERIFIED_SESSION')"
            size="14"
            class="text-s-warning-text my-0 mx-0 min-w-[14px] flex-shrink-0"
            icon="warning"
          />
        </div>

        <div
          class="flex items-center gap-2 overflow-hidden text-xs text-s-muted conversation--header--actions text-ellipsis whitespace-nowrap"
        >
          <span
            v-if="mode"
            class="inline-flex items-center gap-1.5 h-5 px-2 rounded-full text-xs font-medium whitespace-nowrap shrink-0"
            :class="
              mode === 'human'
                ? 'bg-s-bubble-human text-s-bubble-human-text'
                : 'bg-s-brand-soft text-s-brand-text'
            "
          >
            <span
              v-if="mode === 'bot'"
              class="size-1.5 rounded-full shrink-0"
              :class="botDotClass"
            />
            {{ controlLabel }}
          </span>
          <SynapseStatusBadge
            v-if="stageBadge"
            v-bind="stageBadge"
            size="sm"
            class="shrink-0"
          />
          <InboxName v-if="hasMultipleInboxes" :inbox="inbox" class="!mx-0" />
          <span v-if="isSnoozed" class="font-semibold text-s-warning-text">
            {{ snoozedDisplayText }}
          </span>
        </div>
      </div>
    </div>
    <div
      class="flex flex-row items-center justify-start xl:justify-end flex-shrink-0 gap-2 w-full xl:w-auto header-actions-wrap"
    >
      <SLACardLabel
        v-if="hasSlaPolicyId"
        :chat="chat"
        show-extended-info
        :parent-width="width"
        class="hidden md:flex"
      />
      <Button
        v-if="isAutonomous"
        size="sm"
        icon="i-lucide-hand"
        :label="$t('SYNAPSEOS.CONVERSATION.CONTROL.TAKE_OVER')"
        @click="takeOver"
      />
      <MoreActions :conversation-id="currentChat.id" />
      <SidepanelSwitch />
    </div>
  </div>
</template>
