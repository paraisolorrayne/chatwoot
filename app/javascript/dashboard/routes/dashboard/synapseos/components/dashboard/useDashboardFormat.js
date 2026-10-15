// CUSTOMIZAÇÃO_SYNAPSEOS — formatação do dashboard executivo no locale do
// usuário (Intl): números, %, BRL, datas/horas, tempo relativo e nomes.
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';

const NAME_PARTICLES = ['da', 'das', 'de', 'do', 'dos', 'e'];

export const useDashboardFormat = () => {
  const { locale } = useI18n();
  const tag = computed(() => locale.value.replace('_', '-'));

  const formatNumber = value => new Intl.NumberFormat(tag.value).format(value);

  // Recebe a taxa já em % (12.5 => "12,5%" em pt-BR).
  const formatPercent = value =>
    new Intl.NumberFormat(tag.value, {
      style: 'percent',
      maximumFractionDigits: 1,
    }).format(value / 100);

  // `compact` para espaços apertados: "R$ 4,4 mi".
  const formatCurrency = (value, { compact = false } = {}) =>
    new Intl.NumberFormat(tag.value, {
      style: 'currency',
      currency: 'BRL',
      notation: compact ? 'compact' : 'standard',
      maximumFractionDigits: compact ? 1 : 0,
    }).format(value);

  // "2026-10-15" => "15/10" (pt-BR).
  const formatDayMonth = isoDate =>
    new Date(`${isoDate}T00:00:00`).toLocaleDateString(tag.value, {
      day: '2-digit',
      month: '2-digit',
    });

  const formatTime = timestamp =>
    new Date(timestamp).toLocaleTimeString(tag.value, {
      hour: '2-digit',
      minute: '2-digit',
    });

  const formatRelative = (iso, now) => {
    const seconds = Math.round((new Date(iso).getTime() - now) / 1000);
    const rtf = new Intl.RelativeTimeFormat(tag.value, {
      numeric: 'auto',
      style: 'short',
    });
    const abs = Math.abs(seconds);
    if (abs < 3600) return rtf.format(Math.round(seconds / 60), 'minute');
    if (abs < 86400) return rtf.format(Math.round(seconds / 3600), 'hour');
    return rtf.format(Math.round(seconds / 86400), 'day');
  };

  // Nomes vindos do WhatsApp/planilha às vezes chegam em CAIXA ALTA:
  // "MARIA DA SILVA" => "Maria da Silva". Outros formatos ficam como vieram.
  const formatPersonName = name => {
    if (!name || name !== name.toLocaleUpperCase(tag.value)) return name;
    return name
      .toLocaleLowerCase(tag.value)
      .split(' ')
      .map((word, index) =>
        index > 0 && NAME_PARTICLES.includes(word)
          ? word
          : word.charAt(0).toLocaleUpperCase(tag.value) + word.slice(1)
      )
      .join(' ');
  };

  return {
    formatNumber,
    formatPercent,
    formatCurrency,
    formatDayMonth,
    formatTime,
    formatRelative,
    formatPersonName,
  };
};
