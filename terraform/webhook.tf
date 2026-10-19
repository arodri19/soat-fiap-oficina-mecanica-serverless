# Fase 4: ponto de entrada HTTPS para o webhook do Mercado Pago.
# O billing-service roda no EKS atrás de um LoadBalancer http; a API Gateway
# (já https) repassa a notificação como proxy HTTP. A autenticação é a própria
# assinatura x-signature do Mercado Pago, validada no billing — por isso a rota
# não usa o autorizador JWT. Configure no painel do Mercado Pago (Suas integrações
# > Webhooks) e na variável BILLING_PUBLIC_URL do billing a URL do output
# mercadopago_webhook_url.
resource "aws_apigatewayv2_integration" "mercadopago_webhook" {
  count = var.billing_webhook_upstream_url == "" ? 0 : 1

  api_id             = aws_apigatewayv2_api.this.id
  integration_type   = "HTTP_PROXY"
  integration_method = "POST"
  integration_uri    = "${trimsuffix(var.billing_webhook_upstream_url, "/")}/api/webhooks/mercadopago"
}

resource "aws_apigatewayv2_route" "mercadopago_webhook" {
  count = var.billing_webhook_upstream_url == "" ? 0 : 1

  api_id    = aws_apigatewayv2_api.this.id
  route_key = "POST /api/webhooks/mercadopago"
  target    = "integrations/${aws_apigatewayv2_integration.mercadopago_webhook[0].id}"
}
