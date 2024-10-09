provider "aws" {
    region = "us-east-1"
}

terraform {
    required_providers {
        aws = {
            source  = "hashicorp/aws"
            version = "~> 3.0"
        }
    }
    backend "s3" {
        bucket = "clash-terraform-state"
      
    }
}

data "aws_iam_role" "lambda-role" {
    name = "lambdas"
}

resource "aws_lambda_function" "clash-user" {
    filename      = "../get-user-lambda.zip"
    function_name = "get-user-lambda"
    role          = data.aws_iam_role.lambda-role.arn
    handler       = "lambdas/get-user/index.getUser"
    runtime       = "nodejs16.x"
}
