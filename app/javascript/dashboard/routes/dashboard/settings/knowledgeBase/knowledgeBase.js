// CUSTOMIZAÇÃO_SYNAPSEOS: utilitários da base de conhecimento de veículos.

// Planilha modelo (formato padrão) servida de public/.
export const TEMPLATE_URL = '/synapseos/base-conhecimento-modelo.xlsx';

export const formatPrice = (value, locale = 'pt-BR') => {
  if (value === null || value === undefined) return '—';
  return new Intl.NumberFormat(locale.replace('_', '-'), {
    style: 'currency',
    currency: 'BRL',
    maximumFractionDigits: 0,
  }).format(value);
};

export const normalizeText = value =>
  String(value || '')
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .toLowerCase()
    .trim();
