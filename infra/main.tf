provider "aws" {
    region = "us-east-1"
}

terraform {
    required_providers {
        aws = {
            source  = "hashicorp/aws"
            version = "~> 5.0"
        }
    }
    backend "s3" {
        bucket = "clash-terraform-state"
        key = "lambdas/terraform.tfstate"
    }
}

data "aws_iam_role" "lambda_role" {
    name = "lambdas"
}

resource "aws_apigatewayv2_api" "clash_gateway" {
    name          = "clash_gateway"
    protocol_type = "HTTP"

}

resource "aws_lambda_function" "clash_user_lambda" {
    filename      = "../get-user-lambda.zip"
    function_name = "get-user-lambda"
    role          = data.aws_iam_role.lambda_role.arn
    handler       = "lambdas/get-user/index.getUser"
    runtime       = "nodejs20.x"
}

resource "aws_apigatewayv2_integration" "clash_user_integration" {
    api_id             = aws_apigatewayv2_api.clash_gateway.id
    integration_type   = "AWS_PROXY"
    integration_uri    = aws_lambda_function.clash_user_lambda.invoke_arn
    integration_method = "POST"
}

resource "aws_apigatewayv2_route" "clash_user_route" {
    api_id    = aws_apigatewayv2_api.clash_gateway.id
    route_key = "GET /user"
    target    = "integrations/${aws_apigatewayv2_integration.clash_user_integration.id}"
}

resource "aws_apigatewayv2_stage" "clash_user_stage" {
  api_id      = aws_apigatewayv2_api.clash_gateway.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_lambda_permission" "clash_user_lambda_permission" {
  statement_id  = "b4404d52-e199-571c-9de1-d80920177fc5"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.clash_user_lambda.arn
  principal     = "apigateway.amazonaws.com"
  source_arn    = "arn:aws:execute-api:us-east-1:394414610569:${aws_apigatewayv2_api.clash_gateway.id}/*/*/user"
}
