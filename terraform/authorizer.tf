# Lambda Authorizer da API Gateway (api-gateway.tf) — valida o JWT emitido pela
# Lambda de login (aws_lambda_function.auth_cpf) antes de deixar uma requisição
# chegar numa rota protegida. Não precisa de VPC (só valida assinatura/claims,
# não acessa o RDS), o que mantém o cold start dela bem mais rápido.

resource "aws_iam_role" "authorizer" {
  name               = "${local.name}-authorizer-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

resource "aws_iam_role_policy_attachment" "authorizer_basic_execution" {
  role       = aws_iam_role.authorizer.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Reaproveita o mesmo pacote (.build/auth-cpf.zip) da Lambda de login — o handler
# do autorizador (src/authorizer.js) já está incluído nele, sem build separado.
resource "aws_lambda_function" "authorizer" {
  function_name = "${local.name}-authorizer"
  role          = aws_iam_role.authorizer.arn
  handler       = "src/authorizer.handler"
  runtime       = var.lambda_runtime
  timeout       = 5
  memory_size   = 128

  filename         = data.archive_file.lambda_auth.output_path
  source_code_hash = data.archive_file.lambda_auth.output_base64sha256

  environment {
    variables = {
      JWT_SECRET = var.jwt_secret
      JWT_ISSUER = local.jwt_issuer
    }
  }
}
