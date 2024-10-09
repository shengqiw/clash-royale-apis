provider "aws" {
    region = "us-east-1"
}

data "aws_iam_role" "lambda-role" {
    name = "lambdas"
}

resource "aws_lambda_function" "clash-user" {
    filename      = "../get-user-lambda.zip"
    function_name = "get-user-lambda"
    role          = aws_iam_role.lambda-role.arn
    handler       = "lambdas/get-user/index.getUser"
    runtime       = "nodejs22.x"
}
