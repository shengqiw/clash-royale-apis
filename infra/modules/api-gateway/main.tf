resource "aws_apigatewayv2_api" "clash_gateway" {
    name          = "clash_gateway"
    protocol_type = "HTTP"

}
resource "aws_apigatewayv2_integration" "clash_user_integration" {
    api_id             = aws_apigatewayv2_api.clash_gateway.id
    integration_type   = "AWS_PROXY"
    integration_uri    = var.lambda_invoke_arn_user
    integration_method = "POST"
}

resource "aws_apigatewayv2_integration" "clash_clan_integration" {
    api_id             = aws_apigatewayv2_api.clash_gateway.id
    integration_type   = "AWS_PROXY"
    integration_uri    = var.lambda_invoke_arn_clan
    integration_method = "POST"
}

resource "aws_apigatewayv2_route" "clash_user_route" {
    api_id    = aws_apigatewayv2_api.clash_gateway.id
    route_key = "GET /user"
    target    = "integrations/${aws_apigatewayv2_integration.clash_user_integration.id}"
}

resource "aws_apigatewayv2_route" "clash_clan_route" {
    api_id    = aws_apigatewayv2_api.clash_gateway.id
    route_key = "GET /clan"
    target    = "integrations/${aws_apigatewayv2_integration.clash_clan_integration.id}"
}

resource "aws_apigatewayv2_stage" "clash_stage_prod" {
  api_id      = aws_apigatewayv2_api.clash_gateway.id
  name        = "$default"
  auto_deploy = true

  default_route_settings {
    throttling_burst_limit = 20
    throttling_rate_limit  = 10
  }
}