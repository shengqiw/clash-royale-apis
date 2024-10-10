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


module "api_gateway" {
    source = "./modules/api-gateway"
}

module "iam_policy" {
    source = "./modules/iam"
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
    depends_on = [module.iam_policy.cloudwatch_policy]

    vpc_config {
        subnet_ids         = data.aws_subnets.private_subnets.ids
        security_group_ids = data.aws_security_groups.lambda_sg.ids
    }
}


resource "aws_lambda_permission" "clash_user_lambda_permission" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.clash_user_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "arn:aws:execute-api:us-east-1:394414610569:${module.api_gateway.clash_gateway.id}/*"
}

resource "aws_cloudwatch_log_group" "lambda_log_group" {
  name              = "/aws/lambda/get-user-lambda"
  retention_in_days = 7
}
