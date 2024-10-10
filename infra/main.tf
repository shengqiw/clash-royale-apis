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

resource "aws_iam_policy" "cloudwatch_policy" {
  name = "lambda_cloudwatch_policy"
  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "*"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_cloudwatch_attach" {
  role       = data.aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.cloudwatch_policy.arn
}

resource "aws_apigatewayv2_api" "clash_gateway" {
    name          = "clash_gateway"
    protocol_type = "HTTP"

}

data "archive_file" "get_user_lambda_zip" {
    type        = "zip"
    source_dir  = "../lambdas/get-user/"
    output_path = "../get-user-lambda.zip"
}

data "aws_subnets" "private_subnets" {
  filter {
    name   = "tag:Name"
    values = ["*private*"]
  }
}

data "aws_security_groups" "lambda_sg" {
  filter {
    name   = "tag:Name"
    values = ["default"]
  }
}


resource "aws_lambda_function" "clash_user_lambda" {
    filename      = data.archive_file.get_user_lambda_zip.output_path
    source_code_hash = data.archive_file.get_user_lambda_zip.output_base64sha256
    function_name = "get-user-lambda"
    role          = data.aws_iam_role.lambda_role.arn
    handler       = "index.getUser"
    runtime       = "nodejs20.x"
    depends_on = [aws_iam_role_policy_attachment.lambda_cloudwatch_attach]

    vpc_config {
        subnet_ids         = data.aws_subnets.private_subnets.ids
        security_group_ids = data.aws_security_groups.lambda_sg.ids
    }
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
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.clash_user_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "arn:aws:execute-api:us-east-1:394414610569:${aws_apigatewayv2_api.clash_gateway.id}/*"
}

resource "aws_cloudwatch_log_group" "lambda_log_group" {
  name              = "/aws/lambda/get-user-lambda"
  retention_in_days = 7
}
