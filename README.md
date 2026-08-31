# soat-fiap-oficina-mecanica-serverless

Function Serverless (AWS Lambda) da oficina mecânica: autenticação de clientes via CPF,
exposta através de uma API Gateway (HTTP API).

## O que esta função faz

Recebe `{ "cpf": "..." }`, e:

1. Valida o CPF (dígito verificador, formato).
2. Consulta a existência do cliente na tabela `ClientPF` do banco da aplicação principal
   (RDS provisionado pelo repositório
   [`soat-fiap-oficina-mecanica-infra-data`](https://github.com/arodri19/soat-fiap-oficina-mecanica-infra-data)).
3. Se o cliente existir, gera e devolve um **JWT** (`sub`, `cpf`, `name`, `role: "CLIENT"`,
   `iss: "oficina-mecanica-app"`), assinado com o **mesmo `JWT_SECRET`** usado pelo login de
   funcionários no repositório
   [`soat-fiap-oficina-mecanica`](https://github.com/arodri19/soat-fiap-oficina-mecanica) —
   por isso o backend principal consegue validar esse token com o middleware `authenticate`
   que já existe lá, sem nenhuma lógica nova de verificação.

Esse token protege as rotas sensíveis voltadas ao cliente (`GET /api/track/:externalId` e
`POST /api/track/:externalId/approve`), que passaram a exigir `Authorization: Bearer <token>`
com `role: "CLIENT"`.

| Situação | Resposta |
|---|---|
| CPF malformado ou com dígito verificador inválido | `400` |
| CPF válido, mas sem cliente cadastrado | `404` |
| CPF válido e cliente encontrado | `200` + `{ token, expiresIn, client }` |

## Arquitetura

```
Cliente (app/site)
      │  POST /auth/cpf  { "cpf": "..." }
      ▼
API Gateway (HTTP API, este repositório)
      │  integração AWS_PROXY
      ▼
Lambda auth-cpf (este repositório)
      │  valida CPF → SELECT ClientPF WHERE cpf = $1 (RDS, infra-data)
      ▼
JWT { sub, cpf, name, role: "CLIENT", iss }  ──►  usado como Bearer token nas
                                                    rotas protegidas
```

Rota protegida (demo — `GET /me`, mesma Lambda): antes de chegar na função, a API Gateway
chama um **Lambda Authorizer** (`src/authorizer.js`) que valida a assinatura e o `iss` do
token com o mesmo `JWT_SECRET`. Sem token válido, a requisição nem chega na Lambda (`401`
direto da API Gateway).

> Não usamos o **authorizer JWT nativo** da API Gateway porque ele exige tokens assinados
> com RS256 e um endpoint JWKS público — nossos tokens são HS256 (segredo compartilhado,
> mesmo formato que o backend principal já valida). Um Lambda Authorizer replica a mesma
> validação sem mudar nada no restante do projeto. Ver
> [`docs/adr/0004-...`](https://github.com/arodri19/soat-fiap-oficina-mecanica) no
> repositório principal para a decisão completa.

A Lambda roda dentro da mesma VPC/subnets privadas do cluster (lidas do repositório
`infra-kube` via `terraform_remote_state`), e o security group do RDS (repositório
`infra-data`) recebe uma regra de ingress liberando essa Lambda — sem duplicar o
provisionamento de rede nem do banco. O autorizador **não** roda na VPC (só valida o
token, não acessa o RDS), o que mantém o cold start dele rápido.

## Estrutura

```
src/
  handler.js      — entrypoint da Lambda de login
  authorizer.js   — Lambda Authorizer da API Gateway (rotas protegidas)
  cpf.js          — validação de CPF (dígito verificador)
  db.js           — consulta ao RDS (pg)
tests/            — testes unitários (jest)
terraform/
  lambda.tf       — Lambda de login (IAM, security group, VPC)
  authorizer.tf   — Lambda Authorizer (IAM)
  api-gateway.tf  — API Gateway HTTP API, rotas e integrações
```

## Desenvolvimento local

```bash
npm install
npm test
```

## Deploy

```bash
# 1. Build do pacote de deploy (src/ + node_modules de produção em dist/) —
#    usado tanto pela Lambda de login quanto pelo autorizador
npm run build

# 2. Provisionar Lambdas + API Gateway
cd terraform
cp terraform.tfvars.example terraform.tfvars
# edite terraform.tfvars — especialmente tf_state_bucket

export TF_VAR_db_password="mesma senha do RDS (infra-data)"
export TF_VAR_jwt_secret="mesmo JWT_SECRET do repositório soat-fiap-oficina-mecanica"

terraform init \
  -backend-config="bucket=<TF_STATE_BUCKET>" \
  -backend-config="key=oficina-mecanica/serverless/terraform.tfstate" \
  -backend-config="region=us-east-1" \
  -backend-config="dynamodb_table=<TF_STATE_LOCK_TABLE>" \
  -backend-config="encrypt=true"

terraform plan
terraform apply
```

Pré-requisitos: os `apply` dos repositórios `infra-kube` (VPC) e `infra-data` (RDS) já
devem ter rodado antes — é deles que vêm a rede e o security group do banco.

## Documentação da API (Swagger)

As rotas deste repositório (`POST /auth/cpf` e `GET /me`) são documentadas no Swagger
da **aplicação principal**, em `GET /api-docs` — cada operação tem um `server` próprio
apontando para a URL desta API Gateway, então o "Try it out" do Swagger já chama o host
certo automaticamente. Ver instruções de acesso no
[README do `soat-fiap-oficina-mecanica`](https://github.com/arodri19/soat-fiap-oficina-mecanica#documentação-da-api).

## Testando

```bash
API_URL=$(terraform -chdir=terraform output -raw api_gateway_url)

# Login (rota pública)
curl -X POST "$API_URL/auth/cpf" \
  -H 'Content-Type: application/json' \
  -d '{"cpf": "529.982.247-25"}'

# Rota protegida (demo) — sem token: 401
curl -i "$API_URL/me"

# Rota protegida (demo) — com token válido: passa pelo autorizador
TOKEN="<token retornado pelo login acima>"
curl -i "$API_URL/me" -H "Authorization: Bearer $TOKEN"
```
