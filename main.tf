##############################################################################
#  TerraConsole — Root Terraform Configuration
#  Managed by TerraConsole — https://github.com/dinsun0101/terraform-ui
##############################################################################

terraform {
  required_version = ">= 1.7.0"
  required_providers {
    aws    = { source = "hashicorp/aws", version = "~> 5.0" }
    random = { source = "hashicorp/random", version = "~> 3.0" }
  }

  # Uncomment to use S3 backend for remote state:
  # backend "s3" {
  #   bucket  = "your-tf-state-bucket"
  #   key     = "terraform.tfstate"
  #   region  = "ap-south-1"
  #   encrypt = true
  # }
}

provider "aws" {
  region = var.region
  default_tags {
    tags = {
      Environment = var.environment
      ManagedBy   = "terraform"
      DeployedVia = "terra-console"
    }
  }
}

locals {
  services      = toset(split(",", var.enabled_services))
  deploy_vpc    = contains(local.services, "vpc")
  deploy_ec2    = contains(local.services, "ec2")
  deploy_rds    = contains(local.services, "rds")
  deploy_s3     = contains(local.services, "s3")
  deploy_iam    = contains(local.services, "iam")
  deploy_lambda = contains(local.services, "lambda")
  deploy_ecs    = contains(local.services, "ecs")
}

# ── VPC ───────────────────────────────────────────────────────────────────
resource "aws_vpc" "main" {
  count                = local.deploy_vpc ? 1 : 0
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = { Name = "${var.environment}-vpc" }
}

data "aws_availability_zones" "available" {
  count = local.deploy_vpc ? 1 : 0
  state = "available"
}

resource "aws_subnet" "public" {
  count                   = local.deploy_vpc ? 2 : 0
  vpc_id                  = aws_vpc.main[0].id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone       = data.aws_availability_zones.available[0].names[count.index]
  map_public_ip_on_launch = true
  tags = { Name = "${var.environment}-public-${count.index + 1}" }
}

resource "aws_subnet" "private" {
  count             = local.deploy_vpc ? 2 : 0
  vpc_id            = aws_vpc.main[0].id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 10)
  availability_zone = data.aws_availability_zones.available[0].names[count.index]
  tags = { Name = "${var.environment}-private-${count.index + 1}" }
}

resource "aws_internet_gateway" "igw" {
  count  = local.deploy_vpc ? 1 : 0
  vpc_id = aws_vpc.main[0].id
  tags   = { Name = "${var.environment}-igw" }
}

resource "aws_route_table" "public" {
  count  = local.deploy_vpc ? 1 : 0
  vpc_id = aws_vpc.main[0].id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw[0].id
  }
  tags = { Name = "${var.environment}-public-rt" }
}

resource "aws_route_table_association" "public" {
  count          = local.deploy_vpc ? 2 : 0
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public[0].id
}

# ── EC2 ───────────────────────────────────────────────────────────────────
data "aws_ami" "amazon_linux" {
  count       = local.deploy_ec2 ? 1 : 0
  most_recent = true
  owners      = ["amazon"]
  filter { name = "name";   values = ["al2023-ami-*-x86_64"] }
  filter { name = "state";  values = ["available"] }
}

resource "aws_security_group" "web" {
  count       = local.deploy_ec2 ? 1 : 0
  name        = "${var.environment}-web-sg"
  description = "Web server security group"
  vpc_id      = local.deploy_vpc ? aws_vpc.main[0].id : var.existing_vpc_id
  ingress { from_port = 80;  to_port = 80;  protocol = "tcp"; cidr_blocks = ["0.0.0.0/0"] }
  ingress { from_port = 443; to_port = 443; protocol = "tcp"; cidr_blocks = ["0.0.0.0/0"] }
  egress  { from_port = 0;   to_port = 0;   protocol = "-1";  cidr_blocks = ["0.0.0.0/0"] }
  tags = { Name = "${var.environment}-web-sg" }
}

resource "aws_instance" "web" {
  count                  = local.deploy_ec2 ? var.ec2_instance_count : 0
  ami                    = data.aws_ami.amazon_linux[0].id
  instance_type          = var.ec2_instance_type
  subnet_id              = local.deploy_vpc ? aws_subnet.public[count.index % 2].id : var.existing_subnet_id
  vpc_security_group_ids = [aws_security_group.web[0].id]
  tags = { Name = "${var.environment}-web-${count.index + 1}" }
}

# ── S3 ────────────────────────────────────────────────────────────────────
resource "random_id" "suffix" {
  count       = local.deploy_s3 ? 1 : 0
  byte_length = 4
}

resource "aws_s3_bucket" "main" {
  count  = local.deploy_s3 ? 1 : 0
  bucket = "${var.project_name}-${var.environment}-${random_id.suffix[0].hex}"
  tags   = { Name = "${var.project_name}-${var.environment}" }
}

resource "aws_s3_bucket_versioning" "main" {
  count  = local.deploy_s3 ? 1 : 0
  bucket = aws_s3_bucket.main[0].id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_public_access_block" "main" {
  count                   = local.deploy_s3 ? 1 : 0
  bucket                  = aws_s3_bucket.main[0].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ── IAM ───────────────────────────────────────────────────────────────────
resource "aws_iam_role" "app" {
  count = local.deploy_iam ? 1 : 0
  name  = "${var.project_name}-${var.environment}-app-role"
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

resource "aws_iam_role_policy_attachment" "ssm" {
  count      = local.deploy_iam ? 1 : 0
  role       = aws_iam_role.app[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "app" {
  count = local.deploy_iam ? 1 : 0
  name  = "${var.project_name}-${var.environment}-profile"
  role  = aws_iam_role.app[0].name
}

# ── Lambda ────────────────────────────────────────────────────────────────
resource "aws_iam_role" "lambda" {
  count = local.deploy_lambda ? 1 : 0
  name  = "${var.project_name}-${var.environment}-lambda-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Action = "sts:AssumeRole", Effect = "Allow", Principal = { Service = "lambda.amazonaws.com" } }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  count      = local.deploy_lambda ? 1 : 0
  role       = aws_iam_role.lambda[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_security_group" "lambda" {
  count       = local.deploy_lambda ? 1 : 0
  name        = "${var.project_name}-${var.environment}-lambda-sg"
  description = "Lambda security group"
  vpc_id      = local.deploy_vpc ? aws_vpc.main[0].id : var.existing_vpc_id
  egress { from_port = 0; to_port = 0; protocol = "-1"; cidr_blocks = ["0.0.0.0/0"] }
}

# ── ECS ───────────────────────────────────────────────────────────────────
resource "aws_ecs_cluster" "main" {
  count = local.deploy_ecs ? 1 : 0
  name  = "${var.project_name}-${var.environment}"
  setting { name = "containerInsights"; value = var.environment == "prod" ? "enabled" : "disabled" }
  tags = { Name = "${var.project_name}-${var.environment}-cluster" }
}

resource "aws_ecs_cluster_capacity_providers" "main" {
  count              = local.deploy_ecs ? 1 : 0
  cluster_name       = aws_ecs_cluster.main[0].name
  capacity_providers = ["FARGATE", "FARGATE_SPOT"]
  default_capacity_provider_strategy {
    capacity_provider = var.environment == "prod" ? "FARGATE" : "FARGATE_SPOT"
    weight            = 100
    base              = 1
  }
}

resource "aws_security_group" "ecs" {
  count       = local.deploy_ecs ? 1 : 0
  name        = "${var.project_name}-${var.environment}-ecs-sg"
  description = "ECS tasks security group"
  vpc_id      = local.deploy_vpc ? aws_vpc.main[0].id : var.existing_vpc_id
  ingress { from_port = 8080; to_port = 8080; protocol = "tcp"; cidr_blocks = ["10.0.0.0/8"] }
  egress  { from_port = 0;    to_port = 0;    protocol = "-1";  cidr_blocks = ["0.0.0.0/0"] }
  tags = { Name = "${var.project_name}-${var.environment}-ecs-sg" }
}
