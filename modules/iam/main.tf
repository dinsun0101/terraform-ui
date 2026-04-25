variable "environment"  {}
variable "project_name" {}

resource "aws_iam_role" "app" {
  name = "${var.project_name}-${var.environment}-app-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = ["ec2.amazonaws.com", "lambda.amazonaws.com"] }
    }]
  })

  tags = { Name = "${var.project_name}-${var.environment}-app-role" }
}

resource "aws_iam_role_policy" "app_s3" {
  name = "s3-access"
  role = aws_iam_role.app.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket"]
      Resource = ["arn:aws:s3:::${var.project_name}-${var.environment}*"]
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.app.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "app" {
  name = "${var.project_name}-${var.environment}-profile"
  role = aws_iam_role.app.name
}

output "role_arn"         { value = aws_iam_role.app.arn }
output "instance_profile" { value = aws_iam_instance_profile.app.name }
