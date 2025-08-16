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
  role       = var.lambda_role_name
  policy_arn = aws_iam_policy.cloudwatch_policy.arn
}