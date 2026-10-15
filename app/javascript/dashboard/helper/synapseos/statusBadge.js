// CUSTOMIZAÇÃO_SYNAPSEOS — mapeamento de estados para o StatusBadge do Fykos.
// Cobre os estágios da pipeline (template audi_sdr), os estados do ADR-003, os
// estados de lead do Fykos e estados operacionais. Estágios de outros templates
// caem no `stage_type` (inbound/open/working/won/lost).

export const STATUS_VARIANTS = [
  'info',
  'primary',
  'warning',
  'success',
  'danger',
  'sombra',
  'neutral',
];

// key normalizada -> { variant, label (chave i18n em SYNAPSEOS.STATUS) }
const STATUS_MAP = {
  // Estágios da pipeline (audi_sdr)
  aguardando_atendimento: { variant: 'info', label: 'LEAD_NOVO' },
  em_atendimento: { variant: 'primary', label: 'COM_A_IA' },
  aguardando_atendimento_humano: {
    variant: 'warning',
    label: 'AGUARDANDO_VENDEDOR',
  },
  futuro: { variant: 'info', label: 'FUTURO' },
  aguardando_visita: { variant: 'warning', label: 'VISITA_MARCADA' },
  veiculo_em_espera: { variant: 'warning', label: 'AGUARDANDO_ESTOQUE' },
  negociacao: { variant: 'warning', label: 'NEGOCIACAO' },
  venda: { variant: 'success', label: 'VENDIDO' },
  encerrado: { variant: 'danger', label: 'SEM_VENDA' },
  // Estados do lead (ADR-003)
  quer: { variant: 'primary', label: 'QUER' },
  quer_depois: { variant: 'info', label: 'QUER_DEPOIS' },
  nao_quer: { variant: 'danger', label: 'NAO_QUER' },
  sem_resposta: { variant: 'neutral', label: 'SEM_RESPOSTA' },
  // Estados de lead do Fykos
  lead_novo: { variant: 'info', label: 'LEAD_NOVO' },
  lead_qualificado: { variant: 'primary', label: 'QUALIFICADO' },
  lead_aguardando_estoque: { variant: 'warning', label: 'AGUARDANDO_ESTOQUE' },
  em_atendimento_vendedor: { variant: 'warning', label: 'COM_O_VENDEDOR' },
  fechado_venda: { variant: 'success', label: 'VENDIDO' },
  fechado_sem_venda: { variant: 'danger', label: 'SEM_VENDA' },
  reconversao_viavel: { variant: 'info', label: 'RECUPERAVEL' },
  em_farming: { variant: 'sombra', label: 'POS_VENDA' },
  lead_descartado: { variant: 'neutral', label: 'DESCARTADO' },
  contato_nao_genuino: { variant: 'neutral', label: 'NAO_GENUINO' },
  // Operação
  autonomo: { variant: 'primary', label: 'AUTONOMO' },
  sombra: { variant: 'sombra', label: 'SOMBRA' },
  ativo: { variant: 'success', label: 'ATIVO' },
  conectado: { variant: 'success', label: 'CONECTADO' },
  pausado: { variant: 'warning', label: 'PAUSADO' },
  pendente: { variant: 'warning', label: 'PENDENTE' },
  desconectado: { variant: 'danger', label: 'DESCONECTADO' },
  inativo: { variant: 'neutral', label: 'INATIVO' },
};

const STAGE_TYPE_VARIANT = {
  inbound: 'info',
  open: 'primary',
  working: 'warning',
  won: 'success',
  lost: 'danger',
};

export const normalizeStatus = value =>
  String(value ?? '')
    .normalize('NFD')
    .replace(/\p{Diacritic}/gu, '')
    .trim()
    .toLowerCase()
    .replace(/[\s\-./]+/g, '_');

export const resolveStatus = (status, { stageType } = {}) => {
  const key = normalizeStatus(status);
  if (!key) return null;
  if (STATUS_MAP[key]) return { key, ...STATUS_MAP[key] };
  return {
    key,
    variant: STAGE_TYPE_VARIANT[stageType] || 'neutral',
    label: null,
  };
};
