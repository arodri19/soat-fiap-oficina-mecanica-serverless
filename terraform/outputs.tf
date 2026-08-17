output "function_name" {
  description = "Nome da função Lambda"
  value       = aws_lambda_function.auth_cpf.function_name
}

output "function_url" {
  description = "URL HTTPS pública da Lambda (Function URL). Configure o Kong (infra-kube) para proxiar até aqui."
  value       = aws_lambda_function_url.auth_cpf.function_url
}
