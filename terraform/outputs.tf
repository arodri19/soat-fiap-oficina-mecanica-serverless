output "function_name" {
  description = "Nome da função Lambda de autenticação"
  value       = aws_lambda_function.auth_cpf.function_name
}

output "authorizer_function_name" {
  description = "Nome da função Lambda do autorizador JWT"
  value       = aws_lambda_function.authorizer.function_name
}

output "api_gateway_url" {
  description = "URL base da API Gateway (HTTP API) — POST /auth/cpf é público, GET /me exige JWT válido no header Authorization."
  value       = aws_apigatewayv2_stage.default.invoke_url
}

output "mercadopago_webhook_url" {
  description = "URL https do webhook do Mercado Pago (configurar no painel do Mercado Pago). Base para BILLING_PUBLIC_URL do billing-service: a mesma URL sem o sufixo /webhooks/mercadopago."
  value       = var.billing_webhook_upstream_url == "" ? null : "${trimsuffix(aws_apigatewayv2_stage.default.invoke_url, "/")}/webhooks/mercadopago"
}
