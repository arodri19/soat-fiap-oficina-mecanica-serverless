const { isValidCpf, normalizeCpf } = require('../src/cpf');

describe('normalizeCpf', () => {
  it('remove pontuação', () => {
    expect(normalizeCpf('529.982.247-25')).toBe('52998224725');
  });

  it('lida com valores vazios/nulos', () => {
    expect(normalizeCpf(undefined)).toBe('');
    expect(normalizeCpf(null)).toBe('');
  });
});

describe('isValidCpf', () => {
  it('aceita CPF válido sem formatação', () => {
    expect(isValidCpf('52998224725')).toBe(true);
  });

  it('aceita CPF válido formatado', () => {
    expect(isValidCpf('529.982.247-25')).toBe(true);
    expect(isValidCpf('111.444.777-35')).toBe(true);
  });

  it('rejeita CPF com dígito verificador errado', () => {
    expect(isValidCpf('52998224700')).toBe(false);
  });

  it('rejeita CPF com todos os dígitos iguais', () => {
    expect(isValidCpf('11111111111')).toBe(false);
    expect(isValidCpf('00000000000')).toBe(false);
  });

  it('rejeita CPF com tamanho incorreto', () => {
    expect(isValidCpf('123456789')).toBe(false);
    expect(isValidCpf('123456789012')).toBe(false);
  });

  it('rejeita valores vazios/nulos', () => {
    expect(isValidCpf('')).toBe(false);
    expect(isValidCpf(undefined)).toBe(false);
  });
});
