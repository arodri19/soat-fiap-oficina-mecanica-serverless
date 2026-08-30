const jwt = require('jsonwebtoken');

// Lambda Authorizer (REQUEST, "simple responses") da API Gateway HTTP API — protege
// as rotas que exigem login. Valida o token exatamente como o middleware `authenticate`
// do backend principal (jwt.verify com o mesmo segredo), então um token aceito aqui
// também é aceito lá. O claim "iss" identifica que o token veio da Lambda de login
// deste mesmo projeto (ver JWT_ISSUER em handler.js).
exports.handler = async (event) => {
  const authHeader = event.headers?.authorization || event.headers?.Authorization;
  if (!authHeader?.startsWith('Bearer ')) {
    return { isAuthorized: false };
  }

  const token = authHeader.slice('Bearer '.length);
  try {
    const payload = jwt.verify(token, process.env.JWT_SECRET, { issuer: process.env.JWT_ISSUER });
    return {
      isAuthorized: true,
      context: { sub: String(payload.sub ?? ''), role: payload.role ?? '' }
    };
  } catch (error) {
    return { isAuthorized: false };
  }
};
