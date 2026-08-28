const { Pool } = require('pg');

let pool;

// Reaproveita a conexão entre invocações "quentes" da Lambda (mesmo container).
// max: 1 porque cada execução só faz uma consulta — evita esgotar conexões do RDS
// quando a Lambda escala com vários containers simultâneos.
function getPool() {
  if (!pool) {
    pool = new Pool({
      host: process.env.DB_HOST,
      port: Number(process.env.DB_PORT || 5432),
      database: process.env.DB_NAME,
      user: process.env.DB_USER,
      password: process.env.DB_PASSWORD,
      max: 1,
      ssl: { rejectUnauthorized: false }
    });
  }
  return pool;
}

async function findClientByCpf(cpf) {
  const { rows } = await getPool().query(
    'SELECT id, name, cpf FROM "ClientPF" WHERE cpf = $1 LIMIT 1',
    [cpf]
  );
  return rows[0] || null;
}

module.exports = { getPool, findClientByCpf };
