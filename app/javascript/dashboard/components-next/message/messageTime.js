// CUSTOMIZAÇÃO_SYNAPSEOS — datas da thread no idioma do usuário, relógio 24h.
import {
  fromUnixTime,
  isSameDay,
  isSameYear,
  isToday,
  isYesterday,
} from 'date-fns';

const format = (date, locale, options) => {
  const withYear = isSameYear(date, new Date()) ? {} : { year: 'numeric' };
  return new Intl.DateTimeFormat(locale.replace('_', '-'), {
    ...options,
    ...withYear,
  }).format(date);
};

// "15:20" hoje, "12 de out., 15:20" nos outros dias.
export const formatMessageTime = (time, locale) => {
  const date = fromUnixTime(time);
  const clock = { hour: '2-digit', minute: '2-digit', hourCycle: 'h23' };
  if (isToday(date)) return format(date, locale, clock);

  return format(date, locale, { day: 'numeric', month: 'short', ...clock });
};

export const isDifferentDay = (time, previousTime) =>
  !isSameDay(fromUnixTime(time), fromUnixTime(previousTime));

// "Hoje", "Ontem" ou "12 de out." para o separador de dias.
export const formatDayLabel = (time, locale, { today, yesterday }) => {
  const date = fromUnixTime(time);
  if (isToday(date)) return today;
  if (isYesterday(date)) return yesterday;

  return format(date, locale, { day: 'numeric', month: 'short' });
};
