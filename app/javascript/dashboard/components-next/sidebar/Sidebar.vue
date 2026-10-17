<script setup>
import { ref, computed, onMounted } from 'vue';
import { provideSidebarContext, useSidebarResize } from './provider';
import { useAccount } from 'dashboard/composables/useAccount';
import { useKbd } from 'dashboard/composables/utils/useKbd';
import { useMapGetter } from 'dashboard/composables/store';
import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';
import { useAdmin } from 'dashboard/composables/useAdmin';
import { usePolicy } from 'dashboard/composables/usePolicy';
import { getUserPermissions } from 'dashboard/helper/permissionsHelper';
import { useRouter } from 'vue-router';
import { useSidebarKeyboardShortcuts } from './useSidebarKeyboardShortcuts';
import { vOnClickOutside } from '@vueuse/components';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';
import { useWindowSize, useEventListener } from '@vueuse/core';
import { emitter } from 'shared/helpers/mitt';
import { BUS_EVENTS } from 'shared/constants/busEvents';

import Button from 'dashboard/components-next/button/Button.vue';
import SidebarGroup from './SidebarGroup.vue';
import SidebarGroupSeparator from './SidebarGroupSeparator.vue';
import SidebarProfileMenu from './SidebarProfileMenu.vue';
import SidebarChangelogCard from './SidebarChangelogCard.vue';
import SidebarChangelogButton from './SidebarChangelogButton.vue';
import SidebarAccountSwitcher from './SidebarAccountSwitcher.vue';
import SidebarNotificationBell from './SidebarNotificationBell.vue';
import Logo from 'next/icon/Logo.vue';
import ComposeConversation from 'dashboard/components-next/NewConversation/ComposeConversation.vue';
import { useAgentMetricsStore } from 'dashboard/store/synapseos/useAgentMetrics';

const props = defineProps({
  isMobileSidebarOpen: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits([
  'closeKeyShortcutModal',
  'openKeyShortcutModal',
  'showCreateAccountModal',
  'closeMobileSidebar',
]);

const { accountScopedRoute, isOnChatwootCloud } = useAccount();
const store = useStore();
const searchShortcut = useKbd([`$mod`, 'k']);
const { t } = useI18n();

// CUSTOMIZAÇÃO_SYNAPSEOS: itens técnicos do menu de Settings (Inboxes,
// Agent Bots, Custom Attributes, Integrations) ficam VISÍVEIS só pra
// administradores. Agents não veem — esses são setup técnico de operação.
const { isAdmin } = useAdmin();

// CUSTOMIZAÇÃO_SYNAPSEOS: atalho pro painel agentic (a "plataforma"), aberto
// embutido no chat (PlatformPage.vue) com o login do Chatwoot. O painel tem
// deploy e credenciais de todos os clientes: só a equipe Dexi vê
// (permissão synapseos_platform, ver AccountUser#synapseos_staff?).
const router = useRouter();
const currentUser = useMapGetter('getCurrentUser');
const accountId = useMapGetter('getCurrentAccountId');
const isPlatformUser = computed(() =>
  getUserPermissions(currentUser.value, accountId.value).includes(
    'synapseos_platform'
  )
);
const openPlatform = () =>
  router.push(accountScopedRoute('synapseos_platform'));

const isACustomBrandedInstance = useMapGetter(
  'globalConfig/isACustomBrandedInstance'
);
const isRTL = useMapGetter('accounts/isRTL');

const { width: windowWidth } = useWindowSize();
const isMobile = computed(() => windowWidth.value < 768);

const isFeatureEnabledonAccount = useMapGetter(
  'accounts/isFeatureEnabledonAccount'
);

const hasAdvancedAssignment = computed(() => {
  return isFeatureEnabledonAccount.value(
    accountId.value,
    FEATURE_FLAGS.ADVANCED_ASSIGNMENT
  );
});

const toggleShortcutModalFn = show => {
  if (show) {
    emit('openKeyShortcutModal');
  } else {
    emit('closeKeyShortcutModal');
  }
};

useSidebarKeyboardShortcuts(toggleShortcutModalFn);

const expandedItem = ref(null);

const setExpandedItem = name => {
  expandedItem.value = expandedItem.value === name ? null : name;
};

const {
  sidebarWidth,
  isCollapsed,
  setSidebarWidth,
  saveWidth,
  snapToCollapsed,
  snapToExpanded,
  COLLAPSED_THRESHOLD,
} = useSidebarResize();

// On mobile, sidebar is always expanded (flyout mode)
const isEffectivelyCollapsed = computed(
  () => !isMobile.value && isCollapsed.value
);

// Resize handle logic
const isResizing = ref(false);
const startX = ref(0);
const startWidth = ref(0);

provideSidebarContext({
  expandedItem,
  setExpandedItem,
  isCollapsed: isEffectivelyCollapsed,
  sidebarWidth,
  isResizing,
});

// Get clientX from mouse or touch event
const getClientX = event =>
  event.touches ? event.touches[0].clientX : event.clientX;

const onResizeStart = event => {
  isResizing.value = true;
  startX.value = getClientX(event);
  startWidth.value = sidebarWidth.value;
  Object.assign(document.body.style, {
    cursor: 'col-resize',
    userSelect: 'none',
  });
  // Prevent default to avoid scrolling on touch
  event.preventDefault();
};

const onResizeMove = event => {
  if (!isResizing.value) return;

  const delta = isRTL.value
    ? startX.value - getClientX(event)
    : getClientX(event) - startX.value;
  setSidebarWidth(startWidth.value + delta);
};

const onResizeEnd = () => {
  if (!isResizing.value) return;

  isResizing.value = false;
  Object.assign(document.body.style, { cursor: '', userSelect: '' });

  // Snap to collapsed state if below threshold
  if (sidebarWidth.value < COLLAPSED_THRESHOLD) {
    snapToCollapsed();
  } else {
    saveWidth();
  }
};

const onResizeHandleDoubleClick = () => {
  if (isCollapsed.value) snapToExpanded();
  else snapToCollapsed();
};

// Support both mouse and touch events
useEventListener(document, 'mousemove', onResizeMove);
useEventListener(document, 'mouseup', onResizeEnd);
useEventListener(document, 'touchmove', onResizeMove, { passive: false });
useEventListener(document, 'touchend', onResizeEnd);

// CUSTOMIZAÇÃO_SYNAPSEOS: getters/dispatches de labels, teams, customViews
// e sortedInboxes foram removidos do sidebar — os submenus que os consumiam
// (Conversas > Folders/Teams/Channels/Labels, Contatos > Segments/Tagged)
// não existem mais. Notification count segue porque Caixa de Entrada usa.
// CUSTOMIZAÇÃO_SYNAPSEOS: lista de squad ativo (AgentBots cadastrados) define
// se o item "Esquadrão / Métricas" aparece no nav.
const agentMetricsStore = useAgentMetricsStore();
const hasSynapseosAgents = computed(() => agentMetricsStore.hasActiveAgents);

onMounted(() => {
  store.dispatch('inboxes/get');
  store.dispatch('notifications/unReadCount');
  store.dispatch('attributes/get');
  if (accountId.value) {
    agentMetricsStore.fetchActiveAgents({ accountId: accountId.value });
  }
});

const closeMobileSidebar = () => {
  if (!props.isMobileSidebarOpen) return;
  emit('closeMobileSidebar');
};

const onComposeOpen = toggleFn => {
  toggleFn();
  emitter.emit(BUS_EVENTS.NEW_CONVERSATION_MODAL, true);
};

const onComposeClose = () => {
  emitter.emit(BUS_EVENTS.NEW_CONVERSATION_MODAL, false);
};

// CUSTOMIZAÇÃO_SYNAPSEOS: o menu é dividido em seções (trabalho do dia,
// Análises, Agentes de IA, administração). Cada seção só aparece se o usuário
// enxerga pelo menos um item dela, para não sobrar título solto.
const { shouldShow } = usePolicy();
const canSee = item => {
  if (item.children) return item.children.some(canSee);
  if (!item.to) return false;
  const { meta = {} } = router.resolve(item.to);
  return shouldShow(meta.featureFlag, meta.permissions, meta.installationTypes);
};

const menuSections = computed(() =>
  [
    {
      key: 'work',
      items: [
        // CUSTOMIZAÇÃO_SYNAPSEOS: Caixa de Entrada aponta direto pra lista de
        // todas as conversas (antes era a tela de notificações pessoais
        // inbox_view). O item 'Conversas' foi removido da sidebar; as sub-rotas
        // (Mentions, Participating, Unattended, Folders, Teams, Channels,
        // Labels) continuam acessíveis por URL e pelos filtros da lista.
        // Sem badge de não-lidos: o cliente não usa o contador.
        {
          name: 'Inbox',
          label: t('SIDEBAR.INBOX'),
          icon: 'i-lucide-inbox',
          to: accountScopedRoute('home'),
          activeOn: [
            'home',
            'inbox_conversation',
            'conversation_through_mentions',
            'conversation_through_participating',
            'conversation_through_unattended',
            'conversations_through_folders',
            'conversations_through_team',
            'conversation_through_inbox',
            'conversations_through_label',
          ],
        },
        {
          name: 'SynapseOS Pipeline',
          label: t('SIDEBAR.SYNAPSEOS_PIPELINE'),
          icon: 'i-lucide-square-kanban',
          to: accountScopedRoute('synapseos_pipeline'),
          activeOn: ['synapseos_pipeline'],
        },
        {
          name: 'SynapseOS Live Agents',
          label: t('SIDEBAR.SYNAPSEOS_LIVE_AGENTS'),
          icon: 'i-lucide-users',
          to: accountScopedRoute('synapseos_live_agents'),
          activeOn: ['synapseos_live_agents'],
        },
      ],
    },
    {
      key: 'analytics',
      label: t('SIDEBAR.SECTION_ANALYTICS'),
      items: [
        {
          name: 'SynapseOS Dashboard',
          label: t('SIDEBAR.SYNAPSEOS_DASHBOARD'),
          icon: 'i-lucide-layout-dashboard',
          to: accountScopedRoute('synapseos_dashboard'),
          activeOn: ['synapseos_dashboard'],
        },
        {
          name: 'SynapseOS Intelligence',
          label: t('SIDEBAR.SYNAPSEOS_INTELLIGENCE'),
          icon: 'i-lucide-sparkles',
          to: accountScopedRoute('synapseos_intelligence'),
          activeOn: ['synapseos_intelligence'],
        },
        // CUSTOMIZAÇÃO_SYNAPSEOS: Relatórios mantém visão geral (Conversation),
        // performance por agente e o relatório mensal da IA (antes escondido
        // em Configurações). CSAT, SLA, Robôs, Time, Caixa de Entrada e
        // Etiquetas saíram do nav; as rotas /reports/* seguem por URL.
        {
          name: 'Reports',
          label: t('SIDEBAR.REPORTS'),
          icon: 'i-lucide-chart-spline',
          children: [
            {
              name: 'Report Conversation',
              label: t('SIDEBAR.REPORTS_CONVERSATION'),
              to: accountScopedRoute('conversation_reports'),
            },
            {
              name: 'Reports Agent',
              label: t('SIDEBAR.REPORTS_AGENT'),
              to: accountScopedRoute('agent_reports_index'),
              activeOn: ['agent_reports_show'],
            },
            {
              name: 'Reports Monthly',
              label: t('SIDEBAR.REPORTS_MONTHLY'),
              to: accountScopedRoute('monthly_reports_index'),
            },
          ],
        },
      ],
    },
    {
      key: 'ai',
      label: t('SIDEBAR.SECTION_AI'),
      items: [
        // CUSTOMIZAÇÃO_SYNAPSEOS: o que a IA sabe (modelos, versões, preços)
        // fica à vista de quem administra, não no fim de Configurações.
        {
          name: 'Knowledge Base',
          label: t('SIDEBAR.KNOWLEDGE_BASE'),
          icon: 'i-lucide-book-open',
          to: accountScopedRoute('knowledge_base_index'),
        },
        // CUSTOMIZAÇÃO_SYNAPSEOS: Métricas de Agentes só aparece quando há
        // pelo menos um AgentBot cadastrado (squadron_role ou nome legado).
        ...(hasSynapseosAgents.value
          ? [
              {
                name: 'SynapseOS Agent Metrics',
                label: t('SIDEBAR.SYNAPSEOS_AGENT_METRICS'),
                icon: 'i-lucide-bot',
                to: accountScopedRoute('synapseos_agent_metrics'),
                activeOn: ['synapseos_agent_metrics'],
              },
            ]
          : []),
      ],
    },
    // CUSTOMIZAÇÃO_SYNAPSEOS: fora do nav ficam Conversas, Captain (o Synapse
    // OS tem o próprio esquadrão de AgentBots), Contatos/Companies (acessíveis
    // pelo painel da conversa), Campaigns, Help Center e Tempo Real
    // (redundante com Equipe ao vivo). As rotas seguem registradas.
    {
      key: 'admin',
      items: [
        {
          name: 'SynapseOS Support',
          label: t('SYNAPSEOS.SUPPORT.TITLE'),
          icon: 'i-lucide-life-buoy',
          to: accountScopedRoute('synapseos_support'),
          activeOn: ['synapseos_support'],
        },
        // CUSTOMIZAÇÃO_SYNAPSEOS: Configurações agrupada por assunto e sem
        // ícone por item (os ícones repetiam os do nível de cima). Itens
        // técnicos (Caixas de Entrada, Atributos, Robôs, Integrações, Conexão
        // WhatsApp) são só de administrator: a rota já exige a permissão.
        {
          name: 'Settings',
          label: t('SIDEBAR.SETTINGS'),
          icon: 'i-lucide-settings',
          children: [
            {
              name: 'Settings Account Settings',
              label: t('SIDEBAR.ACCOUNT_SETTINGS'),
              to: accountScopedRoute('general_settings_index'),
            },
            {
              name: 'Settings Billing',
              label: t('SIDEBAR.BILLING'),
              to: accountScopedRoute('billing_settings_index'),
            },
            {
              name: 'Settings Group Team',
              label: t('SIDEBAR.SETTINGS_GROUP_TEAM'),
              children: [
                {
                  name: 'Settings Agents',
                  label: t('SIDEBAR.AGENTS'),
                  to: accountScopedRoute('agent_list'),
                },
                {
                  name: 'Settings Teams',
                  label: t('SIDEBAR.TEAMS'),
                  activeOn: [
                    'settings_teams_list',
                    'settings_teams_new',
                    'settings_teams_finish',
                    'settings_teams_add_agents',
                    'settings_teams_show',
                    'settings_teams_edit',
                    'settings_teams_edit_members',
                    'settings_teams_edit_finish',
                  ],
                  to: accountScopedRoute('settings_teams_list'),
                },
                ...(hasAdvancedAssignment.value
                  ? [
                      {
                        name: 'Settings Agent Assignment',
                        label: t('SIDEBAR.AGENT_ASSIGNMENT'),
                        activeOn: [
                          'assignment_policy_index',
                          'agent_assignment_policy_index',
                          'agent_assignment_policy_create',
                          'agent_assignment_policy_edit',
                          'agent_capacity_policy_index',
                          'agent_capacity_policy_create',
                          'agent_capacity_policy_edit',
                        ],
                        to: accountScopedRoute('assignment_policy_index'),
                      },
                    ]
                  : []),
              ],
            },
            {
              name: 'Settings Group Service',
              label: t('SIDEBAR.SETTINGS_GROUP_SERVICE'),
              children: [
                {
                  name: 'Settings Labels',
                  label: t('SIDEBAR.LABELS'),
                  to: accountScopedRoute('labels_list'),
                },
                {
                  name: 'Settings Canned Responses',
                  label: t('SIDEBAR.CANNED_RESPONSES'),
                  to: accountScopedRoute('canned_list'),
                },
                {
                  name: 'Settings Macros',
                  label: t('SIDEBAR.MACROS'),
                  to: accountScopedRoute('macros_wrapper'),
                },
                {
                  name: 'Settings Automation',
                  label: t('SIDEBAR.AUTOMATION'),
                  to: accountScopedRoute('automation_list'),
                },
                {
                  name: 'Conversation Workflow',
                  label: t('SIDEBAR.CONVERSATION_WORKFLOW'),
                  to: accountScopedRoute('conversation_workflow_index'),
                },
                {
                  name: 'Settings Sla',
                  label: t('SIDEBAR.SLA'),
                  to: accountScopedRoute('sla_list'),
                },
                ...(isAdmin.value
                  ? [
                      {
                        name: 'Settings Custom Attributes',
                        label: t('SIDEBAR.CUSTOM_ATTRIBUTES'),
                        to: accountScopedRoute('attributes_list'),
                      },
                    ]
                  : []),
              ],
            },
            ...(isAdmin.value
              ? [
                  {
                    name: 'Settings Group Channels',
                    label: t('SIDEBAR.SETTINGS_GROUP_CHANNELS'),
                    children: [
                      {
                        name: 'Settings Inboxes',
                        label: t('SIDEBAR.INBOXES'),
                        activeOn: [
                          'settings_inbox_list',
                          'settings_inbox_show',
                          'settings_inbox_new',
                          'settings_inbox_finish',
                          'settings_inboxes_page_channel',
                          'settings_inboxes_add_agents',
                        ],
                        to: accountScopedRoute('settings_inbox_list'),
                      },
                      {
                        name: 'Settings WhatsApp Connection',
                        label: t('SIDEBAR.WHATSAPP_CONNECTION'),
                        to: accountScopedRoute('whatsapp_connection_index'),
                      },
                      {
                        name: 'Settings Integrations',
                        label: t('SIDEBAR.INTEGRATIONS'),
                        to: accountScopedRoute('settings_applications'),
                      },
                      {
                        name: 'Settings Agent Bots',
                        label: t('SIDEBAR.AGENT_BOTS'),
                        to: accountScopedRoute('agent_bots'),
                      },
                    ],
                  },
                ]
              : []),
            {
              name: 'Settings Group Security',
              label: t('SIDEBAR.SETTINGS_GROUP_SECURITY'),
              children: [
                {
                  name: 'Settings Security',
                  label: t('SIDEBAR.SECURITY'),
                  to: accountScopedRoute('security_settings_index'),
                },
                {
                  name: 'Settings Custom Roles',
                  label: t('SIDEBAR.CUSTOM_ROLES'),
                  to: accountScopedRoute('custom_roles_list'),
                },
                {
                  name: 'Settings Audit Logs',
                  label: t('SIDEBAR.AUDIT_LOGS'),
                  to: accountScopedRoute('auditlogs_list'),
                },
              ],
            },
          ],
        },
      ],
    },
  ]
    .map(section => ({ ...section, items: section.items.filter(canSee) }))
    .filter(section => section.items.length)
);
</script>

<template>
  <aside
    v-on-click-outside="[
      closeMobileSidebar,
      { ignore: ['#mobile-sidebar-launcher'] },
    ]"
    class="bg-s-sidebar flex flex-col text-sm pb-px fixed top-0 ltr:left-0 rtl:right-0 h-full z-40 w-[240px] md:w-auto md:relative md:flex-shrink-0 md:ltr:translate-x-0 md:rtl:translate-x-0 ltr:border-r rtl:border-l border-s-border"
    :class="[
      {
        'shadow-lg md:shadow-none': isMobileSidebarOpen,
        'ltr:-translate-x-full rtl:translate-x-full': !isMobileSidebarOpen,
        'transition-transform duration-200 ease-out md:transition-[width]':
          !isResizing,
      },
    ]"
    :style="isMobile ? undefined : { width: `${sidebarWidth}px` }"
  >
    <section
      class="grid"
      :class="
        isEffectivelyCollapsed ? 'mt-3 mb-4 gap-3 px-1' : 'mt-3 mb-4 gap-3 px-3'
      "
    >
      <div
        class="flex gap-2 items-center min-w-0"
        :class="{
          'justify-center': isEffectivelyCollapsed,
        }"
      >
        <template v-if="isEffectivelyCollapsed">
          <SidebarAccountSwitcher
            is-collapsed
            @show-create-account-modal="emit('showCreateAccountModal')"
          />
        </template>
        <template v-else>
          <div class="grid flex-shrink-0 place-content-center size-6">
            <Logo class="size-4" />
          </div>
          <div class="flex-shrink-0 w-px h-3 bg-s-border" />
          <SidebarAccountSwitcher
            class="flex-grow -mx-1 min-w-0"
            @show-create-account-modal="emit('showCreateAccountModal')"
          />
        </template>
      </div>
      <div
        class="flex gap-2"
        :class="isEffectivelyCollapsed ? 'flex-col items-center' : ''"
      >
        <RouterLink
          v-if="!isEffectivelyCollapsed"
          :to="{ name: 'search' }"
          class="flex gap-2 items-center px-3 w-full h-9 rounded-lg border border-s-border bg-s-subtle text-s-on-dark-muted hover:bg-s-nav-hover hover:text-s-on-dark transition-colors"
        >
          <span class="flex-shrink-0 i-lucide-search size-4" />
          <span class="flex-grow text-start text-sm">
            {{ t('COMBOBOX.SEARCH_PLACEHOLDER') }}
          </span>
          <span
            class="tracking-wide pointer-events-none select-none text-[11px] font-mono"
          >
            {{ searchShortcut }}
          </span>
        </RouterLink>
        <RouterLink
          v-else
          :to="{ name: 'search' }"
          class="flex items-center justify-center size-9 rounded-lg border border-s-border bg-s-subtle text-s-on-dark-muted hover:bg-s-nav-hover hover:text-s-on-dark transition-colors"
          :title="t('COMBOBOX.SEARCH_PLACEHOLDER')"
        >
          <span class="i-lucide-search size-4" />
        </RouterLink>
        <SidebarNotificationBell />
        <ComposeConversation align-position="right" @close="onComposeClose">
          <template #trigger="{ toggle, isOpen }">
            <Button
              icon="i-lucide-pen-line"
              color="slate"
              size="sm"
              :class="[
                isEffectivelyCollapsed
                  ? '!size-9 !outline-s-border !text-s-on-dark-muted !bg-s-subtle hover:!bg-s-nav-hover hover:!text-s-on-dark'
                  : '!h-9 !outline-s-border !text-s-on-dark-muted !bg-s-subtle hover:!bg-s-nav-hover hover:!text-s-on-dark',
                { '!bg-s-nav-hover !text-s-on-dark': isOpen },
              ]"
              @click="onComposeOpen(toggle)"
            />
          </template>
        </ComposeConversation>
      </div>
    </section>
    <nav
      class="grid overflow-y-scroll flex-grow gap-1 pb-5 no-scrollbar min-w-0"
      :class="isEffectivelyCollapsed ? 'px-2' : 'px-3'"
    >
      <ul
        class="flex flex-col gap-0.5 m-0 list-none min-w-0"
        :class="{ 'items-center': isEffectivelyCollapsed }"
      >
        <template v-for="(section, index) in menuSections" :key="section.key">
          <li v-if="index" role="presentation" class="list-none">
            <SidebarGroupSeparator
              v-if="section.label && !isEffectivelyCollapsed"
              :label="section.label"
            />
            <div
              v-else
              class="h-px my-2 bg-s-border"
              :class="isEffectivelyCollapsed ? 'w-6' : 'mx-3'"
            />
          </li>
          <SidebarGroup
            v-for="item in section.items"
            :key="item.name"
            v-bind="item"
          />
        </template>
      </ul>
    </nav>
    <section
      class="flex relative flex-col flex-shrink-0 gap-1 justify-between items-center"
    >
      <div
        class="pointer-events-none absolute inset-x-0 -top-[1.938rem] h-8 bg-gradient-to-t from-s-sidebar to-transparent"
      />
      <SidebarChangelogCard
        v-if="
          isOnChatwootCloud &&
          !isACustomBrandedInstance &&
          !isEffectivelyCollapsed
        "
      />
      <SidebarChangelogButton
        v-if="
          isOnChatwootCloud &&
          !isACustomBrandedInstance &&
          isEffectivelyCollapsed
        "
      />
      <button
        v-if="isPlatformUser"
        type="button"
        :title="t('SIDEBAR.SYNAPSEOS_PLATFORM')"
        class="flex gap-2 items-center px-3 h-9 rounded-lg border border-s-border bg-s-subtle text-s-on-dark-muted hover:bg-s-nav-hover hover:text-s-on-dark transition-colors"
        :class="
          isEffectivelyCollapsed
            ? 'justify-center w-9 px-0'
            : 'w-[calc(100%-1rem)] mx-2'
        "
        @click="openPlatform"
      >
        <span class="flex-shrink-0 i-lucide-layout-grid size-4" />
        <span
          v-if="!isEffectivelyCollapsed"
          class="flex-grow text-start text-sm"
        >
          {{ t('SIDEBAR.SYNAPSEOS_PLATFORM') }}
        </span>
      </button>
      <div
        class="px-2 py-2 flex-shrink-0 flex w-full z-50 gap-2 items-center border-t border-s-border"
        :class="isEffectivelyCollapsed ? 'justify-center' : 'justify-between'"
      >
        <SidebarProfileMenu
          :is-collapsed="isEffectivelyCollapsed"
          @open-key-shortcut-modal="emit('openKeyShortcutModal')"
        />
      </div>
    </section>
    <!-- Resize Handle (desktop only) -->
    <div
      class="hidden md:block absolute top-0 h-full w-1 cursor-col-resize z-40 ltr:right-0 rtl:left-0 group"
      @mousedown="onResizeStart"
      @touchstart="onResizeStart"
      @dblclick="onResizeHandleDoubleClick"
    >
      <div
        class="absolute top-0 h-full w-px ltr:right-0 rtl:left-0 bg-transparent group-hover:bg-s-accent-500 transition-colors"
        :class="{ 'bg-s-accent-500': isResizing }"
      />
    </div>
  </aside>
</template>
