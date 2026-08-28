function calcCheckDigit(base) {
  let sum = 0;
  let weight = base.length + 1;

  for (const digit of base) {
    sum += Number(digit) * weight;
    weight -= 1;
  }

  const rest = sum % 11;
  return rest < 2 ? 0 : 11 - rest;
}

function normalizeCpf(cpf) {
  return String(cpf ?? '').replace(/\D/g, '');
}

function isValidCpf(cpf) {
  const digits = normalizeCpf(cpf);

  if (digits.length !== 11) return false;
  if (/^(\d)\1{10}$/.test(digits)) return false; // ex: 111.111.111-11

  const base = digits.slice(0, 9);
  const digit1 = calcCheckDigit(base);
  const digit2 = calcCheckDigit(base + digit1);

  return digits === `${base}${digit1}${digit2}`;
}

module.exports = { isValidCpf, normalizeCpf };
