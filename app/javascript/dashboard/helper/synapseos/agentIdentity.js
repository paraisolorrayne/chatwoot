// CUSTOMIZAÇÃO_SYNAPSEOS — identidade visual dos agentes de IA (design system Fykos).
// Chave = squadron_role do Synapseos::AgentResolver. A cor sempre aparece junto
// com o nome. Classes literais para o Tailwind gerar.
const AGENT_CLASSES = {
  natalia: {
    bg: 'bg-s-agent-natalia',
    text: 'text-s-agent-natalia',
    border: 'border-s-agent-natalia',
  },
  alice: {
    bg: 'bg-s-agent-alice',
    text: 'text-s-agent-alice',
    border: 'border-s-agent-alice',
  },
  iza: {
    bg: 'bg-s-agent-iza',
    text: 'text-s-agent-iza',
    border: 'border-s-agent-iza',
  },
  luis: {
    bg: 'bg-s-agent-luis',
    text: 'text-s-agent-luis',
    border: 'border-s-agent-luis',
  },
  otto: {
    bg: 'bg-s-agent-otto',
    text: 'text-s-agent-otto',
    border: 'border-s-agent-otto',
  },
  fernanda: {
    bg: 'bg-s-agent-fernanda',
    text: 'text-s-agent-fernanda',
    border: 'border-s-agent-fernanda',
  },
  angela: {
    bg: 'bg-s-agent-angela',
    text: 'text-s-agent-angela',
    border: 'border-s-agent-angela',
  },
  vitor: {
    bg: 'bg-s-agent-vitor',
    text: 'text-s-agent-vitor',
    border: 'border-s-agent-vitor',
  },
};

// Bots sem squadron_role: fallback pelo primeiro nome (mesma regra do
// AgentResolver::NAME_TO_SLUG). Bots de vendas sem papel especializado
// (Elisa etc.) usam a cor do template SDR (natalia).
const normalize = value =>
  String(value ?? '')
    .normalize('NFD')
    .replace(/\p{Diacritic}/gu, '')
    .trim()
    .toLowerCase()
    .split(/\s+/)[0];

export const resolveAgentSlug = ({ squadronRole, name } = {}) =>
  [squadronRole, normalize(name)].find(slug => AGENT_CLASSES[slug]) ||
  'natalia';

export const agentClasses = agent => AGENT_CLASSES[resolveAgentSlug(agent)];
