import { frontendURL } from 'dashboard/helper/URLHelper.js';
import LiveAgentsPage from './pages/LiveAgentsPage.vue';
import DashboardPage from './pages/DashboardPage.vue';
import PipelinePage from './pages/PipelinePage.vue';
import DesignSystemPage from './pages/DesignSystemPage.vue';

// CUSTOMIZAÇÃO_SYNAPSEOS: C-Level squadron metrics (KPIs R$ e % dos 6 agentes).
const AgentMetrics = () => import('./pages/AgentMetrics.vue');

export const routes = [
  {
    path: frontendURL('accounts/:accountId/synapseos/support'),
    name: 'synapseos_support',
    component: () => import('./pages/SupportPage.vue'),
    meta: { permissions: ['administrator', 'agent'] },
  },
  {
    path: frontendURL('accounts/:accountId/synapseos/dashboard'),
    name: 'synapseos_dashboard',
    component: DashboardPage,
    // synapseos_dashboard_viewer: gerentes liberados via ENV SYNAPSEOS_DASHBOARD_VIEWERS
    // (veem KPIs sem ser admin). Demais views seguem admin-only.
    meta: { permissions: ['administrator', 'synapseos_dashboard_viewer'] },
  },
  {
    // Data lake do painel agentic; synapseos_intelligence = quem vê o Dashboard,
    // nas contas atendidas pelo painel (AccountUser#synapseos_intelligence?).
    path: frontendURL('accounts/:accountId/synapseos/inteligencia'),
    name: 'synapseos_intelligence',
    component: () => import('./pages/IntelligencePage.vue'),
    meta: { permissions: ['synapseos_intelligence'] },
  },
  {
    path: frontendURL('accounts/:accountId/synapseos/pipeline'),
    name: 'synapseos_pipeline',
    component: PipelinePage,
    meta: { permissions: ['administrator', 'agent'] },
  },
  {
    path: frontendURL('accounts/:accountId/synapseos/live-agents'),
    name: 'synapseos_live_agents',
    component: LiveAgentsPage,
    meta: { permissions: ['administrator'] },
  },
  {
    path: frontendURL('accounts/:accountId/synapseos/metrics'),
    name: 'synapseos_agent_metrics',
    component: AgentMetrics,
    meta: { permissions: ['administrator'] },
  },
  {
    // Painel agentic embutido: só a equipe Dexi (AccountUser#synapseos_staff?).
    path: frontendURL('accounts/:accountId/synapseos/plataforma'),
    name: 'synapseos_platform',
    component: () => import('./pages/PlatformPage.vue'),
    meta: { permissions: ['synapseos_platform'] },
  },
  {
    path: frontendURL('accounts/:accountId/synapseos/design'),
    name: 'synapseos_design_system',
    component: DesignSystemPage,
    meta: { permissions: ['administrator'] },
  },
];
