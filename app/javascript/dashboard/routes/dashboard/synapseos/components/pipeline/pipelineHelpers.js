// CUSTOMIZAÇÃO_SYNAPSEOS — regras de exibição do board de pipeline (design system Fykos).

export const POLL_INTERVAL_MS = 15000;
export const TOAST_DURATION_MS = 6000;
export const FLASH_DURATION_MS = 1200;
const STALE_AFTER_HOURS = 48;

// Coluna que pede ação humana (destacada no board).
export const ATTENTION_STAGE_SLUG = 'aguardando_atendimento_humano';
// Recolhidas por padrão, além dos estágios de perda.
const COLLAPSED_BY_DEFAULT_SLUGS = ['futuro'];
// Soltar um card nesses tipos encerra o negócio (Lead#sync_deal_with_stage).
const CLOSING_STAGE_TYPES = ['won', 'lost'];

// Cor do estágio é guardada em hex: paleta de gráficos do Fykos (chart-1..8, tema claro).
export const STAGE_COLOR_SWATCHES = [
  { key: 'CYAN', hex: '#0891B2', className: 'bg-s-chart-1' },
  { key: 'GREEN', hex: '#10B981', className: 'bg-s-chart-2' },
  { key: 'SLATE', hex: '#64748B', className: 'bg-s-chart-3' },
  { key: 'AMBER', hex: '#F59E0B', className: 'bg-s-chart-4' },
  { key: 'ROSE', hex: '#F43F5E', className: 'bg-s-chart-5' },
  { key: 'INDIGO', hex: '#6366F1', className: 'bg-s-chart-6' },
  { key: 'VIOLET', hex: '#8B5CF6', className: 'bg-s-chart-7' },
  { key: 'ORANGE', hex: '#F97316', className: 'bg-s-chart-8' },
];

const normalizeText = value =>
  String(value ?? '')
    .normalize('NFD')
    .replace(/\p{Diacritic}/gu, '')
    .trim()
    .toLowerCase();

const normalizeKey = value => normalizeText(value).replace(/[\s\-./]+/g, '_');

// Só valores em formato de slug ("disparo_template") viram texto; texto livre
// ("Cliente loja", "à vista") fica como veio.
export const humanize = value => {
  const text = String(value ?? '').trim();
  if (!/^[\w-]+$/.test(text)) return text;
  const words = text.replace(/[_-]+/g, ' ');
  return words.charAt(0).toUpperCase() + words.slice(1);
};

// Origem do lead -> chave i18n em SYNAPSEOS.PIPELINE.SOURCES. Origem desconhecida
// aparece humanizada (ex. "Cliente loja").
const SOURCE_KEYS = {
  disparo_template: 'DISPARO',
  instagram_lead_ads: 'INSTAGRAM',
  instagram: 'INSTAGRAM',
  log_outgoing: 'WHATSAPP',
  label: 'MANUAL',
};

const sourceLabelKey = key => {
  if (SOURCE_KEYS[key]) return SOURCE_KEYS[key];
  if (key.startsWith('n8n')) return 'WHATSAPP';
  if (key.endsWith('_command')) return 'MANUAL';
  return null;
};

export const sourceLabel = (t, source) => {
  if (!source) return '';
  const key = sourceLabelKey(normalizeKey(source));
  return key ? t(`SYNAPSEOS.PIPELINE.SOURCES.${key}`) : humanize(source);
};

// Balde de horizonte do LeadLifecycle -> chave i18n em SYNAPSEOS.PIPELINE.HORIZONS.
const HORIZON_KEYS = {
  imediato: 'IMMEDIATE',
  '1-3m': 'M1_3',
  '3-6m': 'M3_6',
  '6-12m': 'M6_12',
  '+12m': 'M12_PLUS',
  sem_prazo: 'NO_DEADLINE',
};

export const horizonLabel = (t, value) => {
  if (!value) return '';
  const key = HORIZON_KEYS[value];
  return key ? t(`SYNAPSEOS.PIPELINE.HORIZONS.${key}`) : humanize(value);
};

export const isClosingStage = stage =>
  CLOSING_STAGE_TYPES.includes(stage?.stage_type);

export const isCollapsedByDefault = stage =>
  stage.stage_type === 'lost' ||
  COLLAPSED_BY_DEFAULT_SLUGS.includes(stage.slug);

const hoursSince = iso => (Date.now() - new Date(iso).getTime()) / 36e5;

// Card parado num estágio de atendimento humano há mais de 48 h.
export const isStale = (lead, stage) =>
  stage?.stage_type === 'working' &&
  hoursSince(lead.updated_at) > STALE_AFTER_HOURS;

// Tempo decorrido em unidade compacta ("12 min", "5 h", "3 d").
export const elapsedLabel = (t, iso) => {
  const minutes = Math.max(0, Math.floor(hoursSince(iso) * 60));
  if (minutes < 60)
    return t('SYNAPSEOS.PIPELINE.ELAPSED.MINUTES', { count: minutes });
  if (minutes < 60 * 24)
    return t('SYNAPSEOS.PIPELINE.ELAPSED.HOURS', {
      count: Math.floor(minutes / 60),
    });
  return t('SYNAPSEOS.PIPELINE.ELAPSED.DAYS', {
    count: Math.floor(minutes / (60 * 24)),
  });
};

export const formatDateTime = (locale, iso) =>
  iso
    ? new Date(iso).toLocaleString(locale.replace('_', '-'), {
        dateStyle: 'short',
        timeStyle: 'short',
      })
    : '';

export const formatBRL = amount => {
  if (!amount) return '';
  return new Intl.NumberFormat('pt-BR', {
    style: 'currency',
    currency: 'BRL',
    maximumFractionDigits: 0,
  }).format(amount);
};

export const handlerKey = lead =>
  lead.handler ? `${lead.handler.kind}:${lead.handler.id}` : null;

export const matchesSearch = (lead, query) => {
  const q = normalizeText(query);
  if (!q) return true;
  const text = normalizeText(
    [lead.contact?.name, lead.modelo_interesse].join(' ')
  );
  if (text.includes(q)) return true;
  const digits = q.replace(/\D/g, '');
  const phone = String(lead.contact?.phone_number ?? '').replace(/\D/g, '');
  return digits.length >= 3 && phone.includes(digits);
};

// Estado recolhido por estágio (preferência local do navegador).
const COLLAPSED_STORAGE_KEY = 'synapseos.pipeline.collapsed';

export const readCollapsedState = () => {
  try {
    return JSON.parse(localStorage.getItem(COLLAPSED_STORAGE_KEY)) || {};
  } catch (e) {
    return {};
  }
};

export const writeCollapsedState = state => {
  try {
    localStorage.setItem(COLLAPSED_STORAGE_KEY, JSON.stringify(state));
  } catch (e) {
    // armazenamento indisponível (aba anônima, bloqueado): só não persiste.
  }
};
