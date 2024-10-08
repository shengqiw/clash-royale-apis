provider "aws" {
    region = "us-east-1"
}

data "aws_caller_identity" "role" {}

output "role" {
  value = data.aws_caller_identity.role.account_id
}