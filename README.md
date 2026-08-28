# soat-fiap-oficina-mecanica-serverless

Function Serverless (AWS Lambda) da oficina mecânica: autenticação de clientes via CPF.

## O que esta função faz

Recebe `{ "cpf": "..." }`, e:

1. Valida o CPF (dígito verificador, formato).
2. Consulta a existência do cliente na tabela `ClientPF` do banco da aplicação principal
   (RDS provisionado pelo repositório
   [`soat-fiap-oficina-mecanica-infra-data`](https://github.com/arodri19/soat-fiap-oficina-mecanica-infra-data)).
3. Se o cliente existir, gera e devolve um **JWT** (`sub`, `cpf`, `name`, `role: "CLIENT"`),
   assinado com o **mesmo `JWT_SECRET`** usado pelo login de funcionários no repositório
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
Kong (API Gateway, repositório infra-kube)
      │  proxy para a Lambda Function URL
      ▼
Lambda auth-cpf (este repositório)
      │  valida CPF → SELECT ClientPF WHERE cpf = $1 (RDS, infra-data)
      ▼
JWT { sub, cpf, name, role: "CLIENT" }  ──►  usado como Bearer token nas
                                              rotas /api/track/* da aplicação principal
```

A Lambda roda dentro da mesma VPC/subnets privadas do cluster (lidas do repositório
`infra-kube` via `terraform_remote_state`), e o security group do RDS (repositório
`infra-data`) recebe uma regra de ingress liberando essa Lambda — sem duplicar o
provisionamento de rede nem do banco.

## Estrutura

```
src/
  handler.js   — entrypoint da Lambda
  cpf.js       — validação de CPF (dígito verificador)
  db.js        — consulta ao RDS (pg)
tests/         — testes unitários (jest)
terraform/     — infraestrutura da Lambda (IAM, security group, Function URL)
```

## Desenvolvimento local

```bash
npm install
npm test
```

## Deploy

```bash
# 1. Build do pacote de deploy (src/ + node_modules de produção em dist/)
npm run build

# 2. Provisionar a Lambda
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

## Depois do apply

Pegue o output `function_url` e configure no Kong (repositório `infra-kube`, via Konga
ou Admin API) uma rota pública, por exemplo `POST /auth/cpf`, apontando para essa URL.

## Testando

```bash
curl -X POST "$(terraform -chdir=terraform output -raw function_url)" \
  -H 'Content-Type: application/json' \
  -d '{"cpf": "529.982.247-25"}'
```
