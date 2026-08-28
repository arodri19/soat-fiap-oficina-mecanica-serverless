jest.mock('../src/db', () => ({
  findClientByCpf: jest.fn()
}));

const jwt = require('jsonwebtoken');
const { findClientByCpf } = require('../src/db');
const { handler } = require('../src/handler');

const VALID_CPF = '529.982.247-25';
const VALID_CPF_DIGITS = '52998224725';

beforeEach(() => {
  jest.clearAllMocks();
  process.env.JWT_SECRET = 'test-secret';
  process.env.JWT_EXPIRES_IN = '1h';
});

function invoke(body) {
  return handler({ body: JSON.stringify(body) });
}

describe('handler', () => {
  it('retorna 400 para CPF inválido', async () => {
    const res = await invoke({ cpf: '123' });
    expect(res.statusCode).toBe(400);
    expect(JSON.parse(res.body).message).toMatch(/inválido/i);
    expect(findClientByCpf).not.toHaveBeenCalled();
  });

  it('retorna 400 para corpo malformado', async () => {
    const res = await handler({ body: '{not-json' });
    expect(res.statusCode).toBe(400);
  });

  it('retorna 404 quando o cliente não existe', async () => {
    findClientByCpf.mockResolvedValue(null);
    const res = await invoke({ cpf: VALID_CPF });
    expect(res.statusCode).toBe(404);
    expect(findClientByCpf).toHaveBeenCalledWith(VALID_CPF_DIGITS);
  });

  it('retorna 200 com um JWT válido quando o cliente existe', async () => {
    findClientByCpf.mockResolvedValue({ id: 42, name: 'Maria Silva', cpf: VALID_CPF_DIGITS });

    const res = await invoke({ cpf: VALID_CPF });
    expect(res.statusCode).toBe(200);

    const body = JSON.parse(res.body);
    expect(body.client).toEqual({ id: 42, name: 'Maria Silva' });

    const payload = jwt.verify(body.token, 'test-secret');
    expect(payload).toMatchObject({ sub: 42, cpf: VALID_CPF_DIGITS, name: 'Maria Silva', role: 'CLIENT' });
  });
});
