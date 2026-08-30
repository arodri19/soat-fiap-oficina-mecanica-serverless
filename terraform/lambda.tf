locals {
  name = "${var.project_name}-${var.environment}-auth-cpf"

  # "iss" gravado no JWT emitido (src/handler.js) — o autorizador da API Gateway
  # (authorizer.tf) confere esse claim antes de validar a assinatura.
  jwt_issuer = "oficina-mecanica-app"
}

# ── Security Group da Lambda ───────────────────────────────────────────────────
# Só precisa de egress (para alcançar o RDS); nenhum ingress é necessário.
resource "aws_security_group" "lambda_auth" {
  name        = "${local.name}-sg"
  description = "Security group da Lambda de autenticacao via CPF"
  vpc_id      = data.terraform_remote_state.infra_kube.outputs.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.name}-sg"
  }
}

# Libera o acesso da Lambda ao RDS (regra adicionada no SG do banco, gerenciado
# pelo repositório infra-data, sem duplicar o provisionamento do RDS em si).
resource "aws_security_group_rule" "rds_from_lambda" {
  description              = "PostgreSQL from the CPF-auth Lambda (Terraform-managed)"
  type                     = "ingress"
  from_port                = var.db_port
  to_port                  = var.db_port
  protocol                 = "tcp"
  security_group_id        = data.terraform_remote_state.infra_data.outputs.rds_security_group_id
  source_security_group_id = aws_security_group.lambda_auth.id
}

# ── IAM Role de execução ────────────────────────────────────────────────────────
data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda_auth" {
  name               = "${local.name}-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

# Inclui permissões de CloudWatch Logs e de gerenciamento de ENI (obrigatório
# para Lambdas dentro de uma VPC, como esta — precisa alcançar o RDS privado).
resource "aws_iam_role_policy_attachment" "lambda_vpc_access" {
  role       = aws_iam_role.lambda_auth.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# ── Pacote de deploy ─────────────────────────────────────────────────────────
# `npm run build` (rodado no CI antes do apply) gera lambda_build_path com
# src/ + node_modules/ prontos para empacotar.
data "archive_file" "lambda_auth" {
  type        = "zip"
  source_dir  = var.lambda_build_path
  output_path = "${path.module}/.build/auth-cpf.zip"
}

resource "aws_lambda_function" "auth_cpf" {
  function_name = local.name
  role          = aws_iam_role.lambda_auth.arn
  handler       = "src/handler.handler"
  runtime       = var.lambda_runtime
  timeout       = var.lambda_timeout
  memory_size   = var.lambda_memory_size

  filename         = data.archive_file.lambda_auth.output_path
  source_code_hash = data.archive_file.lambda_auth.output_base64sha256

  vpc_config {
    subnet_ids         = data.terraform_remote_state.infra_kube.outputs.private_subnet_ids
    security_group_ids = [aws_security_group.lambda_auth.id]
  }

  environment {
    variables = {
      DB_HOST        = data.terraform_remote_state.infra_data.outputs.db_host
      DB_PORT        = tostring(var.db_port)
      DB_NAME        = var.db_name
      DB_USER        = var.db_username
      DB_PASSWORD    = var.db_password
      JWT_SECRET     = var.jwt_secret
      JWT_EXPIRES_IN = var.jwt_expires_in
      JWT_ISSUER     = local.jwt_issuer
    }
  }

  depends_on = [aws_iam_role_policy_attachment.lambda_vpc_access]
}

# O ponto de entrada público é a API Gateway (api-gateway.tf), não uma Function
# URL direta — assim as rotas sensíveis passam pelo autorizador (authorizer.tf)
# antes de chegar na Lambda.
