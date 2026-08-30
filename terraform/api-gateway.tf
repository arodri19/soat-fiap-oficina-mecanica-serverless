# API Gateway (HTTP API) — substitui o Kong (antes em infra-kube) como ponto de
# entrada público. Não precisa de VPC Link: a integração é direto com as Lambdas
# via proxy AWS_PROXY, e nenhuma rota aqui aponta para dentro da VPC/EKS.

resource "aws_apigatewayv2_api" "this" {
  name          = "${var.project_name}-${var.environment}-api"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.this.id
  name        = "$default"
  auto_deploy = true
}

# ── Rota pública: login por CPF (emite o JWT) — sem autorizador ────────────────
resource "aws_apigatewayv2_integration" "auth_cpf" {
  api_id                 = aws_apigatewayv2_api.this.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.auth_cpf.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "auth_cpf" {
  api_id    = aws_apigatewayv2_api.this.id
  route_key = "POST /auth/cpf"
  target    = "integrations/${aws_apigatewayv2_integration.auth_cpf.id}"
}

resource "aws_lambda_permission" "apigw_auth_cpf" {
  statement_id  = "AllowAPIGatewayInvokeAuthCpf"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.auth_cpf.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.this.execution_arn}/*/*"
}

# ── Autorizador JWT (authorizer.tf) ─────────────────────────────────────────────
resource "aws_apigatewayv2_authorizer" "jwt" {
  api_id                            = aws_apigatewayv2_api.this.id
  name                              = "${var.project_name}-${var.environment}-jwt-authorizer"
  authorizer_type                   = "REQUEST"
  authorizer_uri                    = aws_lambda_function.authorizer.invoke_arn
  authorizer_payload_format_version = "2.0"
  enable_simple_responses           = true
  identity_sources                  = ["$request.header.Authorization"]
  # Sem cache: o mesmo token pode ser revogado a qualquer momento (troca de senha,
  # bloqueio de cliente) — preferimos validar toda vez a servir uma decisão velha.
  authorizer_result_ttl_in_seconds = 0
}

resource "aws_lambda_permission" "apigw_authorizer" {
  statement_id  = "AllowAPIGatewayInvokeAuthorizer"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.authorizer.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.this.execution_arn}/*/*"
}

# ── Rota protegida (demo): exige JWT válido emitido pela rota acima ─────────────
resource "aws_apigatewayv2_integration" "protected_demo" {
  api_id                 = aws_apigatewayv2_api.this.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.auth_cpf.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "protected_demo" {
  api_id             = aws_apigatewayv2_api.this.id
  route_key          = "GET /me"
  target             = "integrations/${aws_apigatewayv2_integration.protected_demo.id}"
  authorization_type = "CUSTOM"
  authorizer_id      = aws_apigatewayv2_authorizer.jwt.id
}

resource "aws_lambda_permission" "apigw_protected_demo" {
  statement_id  = "AllowAPIGatewayInvokeProtectedDemo"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.auth_cpf.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.this.execution_arn}/*/*"
}
