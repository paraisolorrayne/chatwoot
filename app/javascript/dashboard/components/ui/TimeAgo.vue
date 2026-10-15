<script setup>
// CUSTOMIZAÇÃO_SYNAPSEOS: tempos no idioma do usuário (antes "1mo • 10m" e o
// tooltip do date-fns sempre em inglês). Formato curto vem do i18n; o tooltip
// usa Intl com o locale da interface.
import { ref, computed, watch, onMounted, onUnmounted } from 'vue';
import { useI18n } from 'vue-i18n';

const props = defineProps({
  isAutoRefreshEnabled: { type: Boolean, default: true },
  lastActivityTimestamp: { type: [String, Date, Number], default: '' },
  createdAtTimestamp: { type: [String, Date, Number], default: '' },
  conversationId: { type: [String, Number], default: '' },
});

const MINUTE = 60;
const HOUR = MINUTE * 60;
const DAY = HOUR * 24;
const MONTH = DAY * 30;
const YEAR = DAY * 365;
const UNITS = [
  { size: YEAR, unit: 'year', key: 'SYNAPSEOS.CHAT_LIST.TIME_AGO.YEARS' },
  { size: MONTH, unit: 'month', key: 'SYNAPSEOS.CHAT_LIST.TIME_AGO.MONTHS' },
  { size: DAY, unit: 'day', key: 'SYNAPSEOS.CHAT_LIST.TIME_AGO.DAYS' },
  { size: HOUR, unit: 'hour', key: 'SYNAPSEOS.CHAT_LIST.TIME_AGO.HOURS' },
  { size: MINUTE, unit: 'minute', key: 'SYNAPSEOS.CHAT_LIST.TIME_AGO.MINUTES' },
];

const { t, locale } = useI18n();
const localeTag = computed(() => locale.value.replace(/_/g, '-'));

const now = ref(Date.now());
let timer = null;

const secondsSince = timestamp => Math.max(0, now.value / 1000 - timestamp);

const elapsed = timestamp => {
  const seconds = secondsSince(timestamp);
  const match = UNITS.find(({ size }) => seconds >= size);
  return match && { ...match, count: Math.floor(seconds / match.size) };
};

const shortTime = timestamp => {
  const time = elapsed(timestamp);
  if (!time) return t('SYNAPSEOS.CHAT_LIST.TIME_AGO.NOW');
  return t(time.key, { count: time.count }, time.count);
};

// Até 30 dias: "Criado há 3 dias"; depois: "Criado em: 15 de out. de 2026".
const tooltipLine = (timestamp, recentLabel, oldLabel) => {
  if (secondsSince(timestamp) > MONTH) {
    const date = new Intl.DateTimeFormat(localeTag.value, {
      dateStyle: 'medium',
    }).format(new Date(timestamp * 1000));
    return `${oldLabel} ${date}`;
  }
  const time = elapsed(timestamp) || { count: 0, unit: 'second' };
  const relative = new Intl.RelativeTimeFormat(localeTag.value, {
    numeric: 'auto',
  }).format(-time.count, time.unit);
  return `${recentLabel} ${relative}`;
};

const createdAtTime = computed(() => shortTime(props.createdAtTimestamp));
const lastActivityTime = computed(() => shortTime(props.lastActivityTimestamp));

const tooltipText = computed(() =>
  [
    tooltipLine(
      props.createdAtTimestamp,
      t('CHAT_LIST.CHAT_TIME_STAMP.CREATED.LATEST'),
      t('CHAT_LIST.CHAT_TIME_STAMP.CREATED.OLDEST')
    ),
    tooltipLine(
      props.lastActivityTimestamp,
      t('CHAT_LIST.CHAT_TIME_STAMP.LAST_ACTIVITY.ACTIVE'),
      t('CHAT_LIST.CHAT_TIME_STAMP.LAST_ACTIVITY.NOT_ACTIVE')
    ),
  ].join('\n')
);

const refreshTime = () => {
  const seconds = secondsSince(props.lastActivityTimestamp);
  if (seconds > DAY) return DAY * 1000;
  if (seconds > HOUR) return HOUR * 1000;
  return MINUTE * 1000;
};

const createTimer = () => {
  timer = setTimeout(() => {
    now.value = Date.now();
    createTimer();
  }, refreshTime());
};

// A linha da lista virtual é reaproveitada para outra conversa: recalcula e reinicia o timer.
watch(
  () => props.conversationId,
  () => {
    now.value = Date.now();
    if (props.isAutoRefreshEnabled) {
      clearTimeout(timer);
      createTimer();
    }
  }
);

onMounted(() => {
  if (props.isAutoRefreshEnabled) createTimer();
});

onUnmounted(() => clearTimeout(timer));
</script>

<template>
  <div
    v-tooltip.top="{
      content: tooltipText,
      delay: { show: 1000, hide: 0 },
    }"
    class="ml-auto leading-4 text-xxs text-s-muted hover:text-s-muted"
  >
    <span>{{ `${createdAtTime} • ${lastActivityTime}` }}</span>
  </div>
</template>
