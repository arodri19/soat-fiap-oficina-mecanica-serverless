const jwt = require('jsonwebtoken');
const { isValidCpf, normalizeCpf } = require('./cpf');
const { findClientByCpf } = require('./db');

const JWT_EXPIRES_IN = process.env.JWT_EXPIRES_IN || '1h';

function response(statusCode, body) {
  return {
    statusCode,
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body)
  };
}

// Invocada via Lambda Function URL (proxy pelo Kong). Recebe { "cpf": "..." },
// valida o CPF, confirma que o cliente existe na base e devolve um JWT — mesmo
// formato/segredo usado pelo login de funcionários (sub/role), então o backend
// principal valida esse token com o middleware `authenticate` já existente.
exports.handler = async (event) => {
  let cpf;
  try {
    const payload = JSON.parse(event.body || '{}');
    cpf = normalizeCpf(payload.cpf);
  } catch {
    return response(400, { message: 'Corpo da requisição inválido. Envie { "cpf": "..." }.' });
  }

  if (!isValidCpf(cpf)) {
    return response(400, { message: 'CPF inválido.' });
  }

  const client = await findClientByCpf(cpf);
  if (!client) {
    return response(404, { message: 'Cliente não encontrado para o CPF informado.' });
  }

  const token = jwt.sign(
    { sub: client.id, cpf: client.cpf, name: client.name, role: 'CLIENT' },
    process.env.JWT_SECRET,
    { expiresIn: JWT_EXPIRES_IN }
  );

  return response(200, {
    token,
    expiresIn: JWT_EXPIRES_IN,
    client: { id: client.id, name: client.name }
  });
};
