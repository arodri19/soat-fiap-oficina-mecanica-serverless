const jwt = require('jsonwebtoken');
const { handler } = require('../src/authorizer');

const SECRET = 'test-secret';
const ISSUER = 'oficina-mecanica-app';

beforeEach(() => {
  process.env.JWT_SECRET = SECRET;
  process.env.JWT_ISSUER = ISSUER;
});

function invoke(authHeader) {
  return handler({ headers: authHeader ? { authorization: authHeader } : {} });
}

function signToken(payload = {}, options = {}) {
  return jwt.sign({ sub: 42, role: 'CLIENT', ...payload }, SECRET, { issuer: ISSUER, ...options });
}

describe('authorizer', () => {
  it('nega quando não há header Authorization', async () => {
    const res = await invoke(undefined);
    expect(res).toEqual({ isAuthorized: false });
  });

  it('nega quando o header não é "Bearer <token>"', async () => {
    const res = await invoke('Token abc123');
    expect(res).toEqual({ isAuthorized: false });
  });

  it('nega token com assinatura inválida', async () => {
    const token = jwt.sign({ sub: 42 }, 'segredo-errado', { issuer: ISSUER });
    const res = await invoke(`Bearer ${token}`);
    expect(res).toEqual({ isAuthorized: false });
  });

  it('nega token com issuer diferente', async () => {
    const token = jwt.sign({ sub: 42 }, SECRET, { issuer: 'outro-app' });
    const res = await invoke(`Bearer ${token}`);
    expect(res).toEqual({ isAuthorized: false });
  });

  it('nega token expirado', async () => {
    const token = signToken({}, { expiresIn: '-1h' });
    const res = await invoke(`Bearer ${token}`);
    expect(res).toEqual({ isAuthorized: false });
  });

  it('autoriza token válido e devolve sub/role no context', async () => {
    const token = signToken({ sub: 7, role: 'CLIENT' });
    const res = await invoke(`Bearer ${token}`);
    expect(res).toEqual({ isAuthorized: true, context: { sub: '7', role: 'CLIENT' } });
  });
});
