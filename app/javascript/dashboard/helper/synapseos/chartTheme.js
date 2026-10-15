// CUSTOMIZAÇÃO_SYNAPSEOS — tema do Chart.js lido das CSS vars (design system Fykos).
// Paleta: chart-1 métrica principal, chart-2 ganho, chart-3 neutro, chart-4 alerta,
// chart-5 perda, chart-6 projeção, chart-7 categoria, chart-8 secundário.
import { ref, onMounted, onBeforeUnmount } from 'vue';

export const cssColor = (token, alpha = 1) => {
  const value = getComputedStyle(document.body)
    .getPropertyValue(`--s-${token}`)
    .trim();
  return value ? `rgb(${value} / ${alpha})` : 'transparent';
};

export const chartTheme = () => ({
  series: Array.from({ length: 8 }, (_, i) => cssColor(`chart-${i + 1}`)),
  text: cssColor('text-secondary'),
  muted: cssColor('text-muted'),
  grid: cssColor('border'),
  surface: cssColor('surface'),
  primary: cssColor('text-primary'),
});

export const baseChartOptions = () => {
  const theme = chartTheme();
  const font = {
    family: 'Inter, ui-sans-serif, system-ui, sans-serif',
    size: 12,
  };
  return {
    responsive: true,
    maintainAspectRatio: false,
    interaction: { intersect: false, mode: 'index' },
    plugins: {
      legend: {
        position: 'bottom',
        labels: { color: theme.text, font, usePointStyle: true, boxWidth: 8 },
      },
      tooltip: {
        backgroundColor: theme.surface,
        titleColor: theme.primary,
        bodyColor: theme.text,
        borderColor: theme.grid,
        borderWidth: 1,
        titleFont: { ...font, weight: '600' },
        bodyFont: font,
        padding: 10,
      },
    },
    scales: {
      x: {
        grid: { display: false },
        border: { color: theme.grid },
        ticks: { color: theme.muted, font },
      },
      y: {
        beginAtZero: true,
        grid: { color: theme.grid },
        border: { display: false },
        ticks: { color: theme.muted, font, precision: 0 },
      },
    },
  };
};

// Muda quando o tema claro/escuro alterna (body.dark), pra recalcular as cores.
export const useThemeKey = () => {
  const themeKey = ref(0);
  let observer;
  onMounted(() => {
    observer = new MutationObserver(() => {
      themeKey.value += 1;
    });
    observer.observe(document.body, {
      attributes: true,
      attributeFilter: ['class'],
    });
  });
  onBeforeUnmount(() => observer?.disconnect());
  return themeKey;
};
