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
        bucket = "jeetio-clash-terraform-state"
        key = "lambdas/terraform.tfstate"
    }
}

module "api_gateway" {
    source = "./modules/api-gateway"

    lambda_invoke_arn_user = aws_lambda_function.clash_user_lambda.invoke_arn
    lambda_invoke_arn_clan = aws_lambda_function.clash_clan_lambda.invoke_arn

}

module "iam_policy" {
    source = "./modules/iam"
    
    lambda_role_name = data.aws_iam_role.lambda_role.name
}
data "aws_iam_role" "lambda_role" { name = "lambdas" }

data "aws_vpc" "main" {
  filter {
    name   = "tag:Name"
    values = ["default"]
  }
}

data "aws_subnet" "public_subnet" {
  vpc_id            = data.aws_vpc.main.id
  tags              = { Name = "jeetio-public" }
}

resource "aws_subnet" "private_subnet" {
  vpc_id            = data.aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1a"
  tags              = { Name = "jeetio-private" }
}

data "aws_internet_gateway" "igw" {
  filter {
    name   = "tag:Name"
    values = ["default"]
  }
}

data "aws_route_table" "public_rt" {
  filter {
    name   = "tag:Name"
    values = ["default"]
  }
}

data "aws_route" "public_internet_access" {
  route_table_id = data.aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_assoc" {
  subnet_id      = data.aws_subnet.public.id
  route_table_id = data.aws_route_table.public_rt.id
}

resource "aws_route_table" "private_rt" {
  vpc_id = data.aws_vpc.main.id
}

// Target for NAT EC2 instance
resource "aws_route" "private_nat_access" {
  route_table_id         = aws_route_table.private_rt.id
  destination_cidr_block = "0.0.0.0/0"
  instance_id            = aws_instance.nat.id
}

resource "aws_route_table_association" "private_assoc" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private_rt.id
}

# Security groups
resource "aws_security_group" "nat_sg" {
  name        = "jeetio-nat-sg"
  vpc_id      = data.aws_vpc.main.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["YOUR_IP/32"] # Replace later
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "lambda_sg" {
  name   = "jeetio-lambda-sg"
  vpc_id = data.aws_vpc.main.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_iam_role" "ssm_role" {
  name = "nat-ssm-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "ec2.amazonaws.com" },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_policy" {
  role       = aws_iam_role.ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ssm_profile" {
  name = "nat-ssm-profile"
  role = aws_iam_role.ssm_role.name
}

resource "aws_instance" "nat" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = "t4g.nano"
  subnet_id                   = aws_subnet.public.id
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.nat_sg.id]
  depends_on                  = [aws_internet_gateway.igw]
  iam_instance_profile        = aws_iam_instance_profile.ssm_profile.name
  tags = { Name = "jeetio-nat" }

  user_data = <<-EOF
              #!/bin/bash
              sysctl -w net.ipv4.ip_forward=1
              yum install -y iptables-services
              service iptables start
              iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
              service iptables save
              EOF
}

# Allocate EIP to NAT instance
resource "aws_eip_association" "nat_assoc" {
  instance_id = aws_instance.nat.id
  allocation_id = aws_eip.nat.id
}

// GET USER LAMBDA
data "archive_file" "get_user_lambda_zip" {
    type        = "zip"
    source_dir  = "../lambdas/get-user/"
    output_path = "../get-user-lambda.zip"
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
    subnet_ids         = [aws_subnet.private_subnet.id]
    security_group_ids = [aws_security_group.lambda_sg.id]
    }
}


resource "aws_lambda_permission" "clash_user_lambda_permission" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.clash_user_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "arn:aws:execute-api:us-east-1:394414610569:${module.api_gateway.clash_gateway.id}/*"
}

resource "aws_cloudwatch_log_group" "lambda_log_group_user" {
  name              = "/aws/lambda/get-user-lambda"
  retention_in_days = 7
}


// GET CLAN LAMBDA

data "archive_file" "get_clan_lambda_zip" {
    type        = "zip"
    source_dir  = "../lambdas/get-clan/"
    output_path = "../get-clan-lambda.zip"
}

resource "aws_lambda_function" "clash_clan_lambda" {
    filename      = data.archive_file.get_clan_lambda_zip.output_path
    source_code_hash = data.archive_file.get_clan_lambda_zip.output_base64sha256
    function_name = "get-clan-lambda"
    role          = data.aws_iam_role.lambda_role.arn
    handler       = "index.getClan"
    runtime       = "nodejs20.x"
    depends_on = [module.iam_policy.cloudwatch_policy]

    vpc_config {
    subnet_ids         = [aws_subnet.private_subnet.id]
    security_group_ids = [aws_security_group.lambda_sg.id]
    }
}



resource "aws_lambda_permission" "clash_clan_lambda_permission" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.clash_clan_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "arn:aws:execute-api:us-east-1:394414610569:${module.api_gateway.clash_gateway.id}/*"
}

resource "aws_cloudwatch_log_group" "lambda_log_group_clan" {
  name              = "/aws/lambda/get-clan-lambda"
  retention_in_days = 7
}