# ── Projeto ───────────────────────────────────────────────────────────────────

variable "project_name" {
  description = "Nome do projeto — prefixo de todos os recursos AWS"
  type        = string
  default     = "oficina-mecanica"
}

variable "aws_region" {
  description = "Região AWS onde os recursos serão criados"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Ambiente de deployment: dev | staging | prod"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "O valor deve ser dev, staging ou prod."
  }
}

variable "tf_state_bucket" {
  description = "Bucket S3 onde os states dos repositórios infra-kube/infra-data estão armazenados."
  type        = string
}

# ── Lambda ────────────────────────────────────────────────────────────────────

variable "lambda_runtime" {
  description = "Runtime do Node.js na Lambda"
  type        = string
  default     = "nodejs20.x"
}

variable "lambda_timeout" {
  description = "Timeout da Lambda em segundos"
  type        = number
  default     = 10
}

variable "lambda_memory_size" {
  description = "Memória alocada para a Lambda (MB)"
  type        = number
  default     = 256
}

variable "lambda_build_path" {
  description = "Caminho para a pasta com o código já buildado (após `npm run build`), empacotada pelo Terraform."
  type        = string
  default     = "../dist"
}

# ── Banco de dados (RDS, provisionado no repositório infra-data) ───────────────

variable "db_name" {
  description = "Nome do banco de dados PostgreSQL"
  type        = string
  default     = "oficina"
}

variable "db_username" {
  description = "Usuário do RDS usado pela Lambda para consultas de leitura"
  type        = string
  default     = "postgres"
}

variable "db_password" {
  description = "Senha do RDS. Use TF_VAR_db_password ou terraform.tfvars (nunca commitar)"
  type        = string
  sensitive   = true
}

variable "db_port" {
  description = "Porta do PostgreSQL"
  type        = number
  default     = 5432
}

# ── Autenticação ──────────────────────────────────────────────────────────────

variable "jwt_secret" {
  description = "Segredo usado para assinar o JWT — deve ser o MESMO configurado no repositório da aplicação principal (JWT_SECRET), para que o backend valide os tokens emitidos por esta Lambda."
  type        = string
  sensitive   = true
}

variable "jwt_expires_in" {
  description = "Tempo de expiração do JWT emitido (formato aceito pela lib jsonwebtoken, ex: '1h')"
  type        = string
  default     = "1h"
}
