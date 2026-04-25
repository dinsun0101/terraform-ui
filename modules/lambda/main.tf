variable "environment"  {}
variable "project_name" {}
variable "vpc_id"       {}
variable "subnet_ids"   { type = list(string) }

resource "aws_security_group" "lambda" {
  name        = "${var.project_name}-${var.environment}-lambda-sg"
  description = "Lambda security group"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_iam_role" "lambda" {
  name = "${var.project_name}-${var.environment}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# Placeholder function — replace with your actual deployment package
resource "aws_lambda_function" "app" {
  function_name = "${var.project_name}-${var.environment}-app"
  role          = aws_iam_role.lambda.arn
  handler       = "index.handler"
  runtime       = "nodejs20.x"
  filename      = "${path.module}/placeholder.zip"

  vpc_config {
    subnet_ids         = var.subnet_ids
    security_group_ids = [aws_security_group.lambda.id]
  }

  environment {
    variables = {
      ENVIRONMENT = var.environment
    }
  }

  tags = { Name = "${var.project_name}-${var.environment}-app" }

  lifecycle {
    ignore_changes = [filename, source_code_hash]
  }
}

output "function_arn"  { value = aws_lambda_function.app.arn }
output "function_name" { value = aws_lambda_function.app.function_name }
