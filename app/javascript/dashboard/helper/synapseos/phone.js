// CUSTOMIZAÇÃO_SYNAPSEOS — formatação de telefone (componente Phone do Fykos).
// +5534999990000 -> (34) 99999-0000. Números de fora do Brasil ficam como vieram.
export const formatPhone = raw => {
  if (!raw) return '';
  const digits = String(raw).replace(/\D/g, '');
  const national =
    digits.startsWith('55') && digits.length >= 12 ? digits.slice(2) : null;
  if (!national) return String(raw);
  const ddd = national.slice(0, 2);
  const number = national.slice(2);
  if (number.length === 9)
    return `(${ddd}) ${number.slice(0, 5)}-${number.slice(5)}`;
  if (number.length === 8)
    return `(${ddd}) ${number.slice(0, 4)}-${number.slice(4)}`;
  return String(raw);
};
