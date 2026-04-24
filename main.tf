##############################################################################
#  TerraConsole — Root Terraform Configuration
#  Managed by: https://github.com/dinsun0101/terraform-ui
##############################################################################

terraform {
  required_version = ">= 1.7.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Uncomment to use S3 backend for remote state
  # backend "s3" {
  #   bucket  = "your-terraform-state-bucket"
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

resource "aws_subnet" "public" {
  count             = local.deploy_vpc ? 2 : 0
  vpc_id            = aws_vpc.main[0].id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone = data.aws_availability_zones.available[0].names[count.index]
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

data "aws_availability_zones" "available" {
  count = local.deploy_vpc ? 1 : 0
  state = "available"
}

# ── EC2 ───────────────────────────────────────────────────────────────────
data "aws_ami" "amazon_linux" {
  count       = local.deploy_ec2 ? 1 : 0
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

resource "aws_security_group" "web" {
  count       = local.deploy_ec2 ? 1 : 0
  name        = "${var.environment}-web-sg"
  vpc_id      = local.deploy_vpc ? aws_vpc.main[0].id : var.existing_vpc_id
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
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
resource "aws_s3_bucket" "main" {
  count  = local.deploy_s3 ? 1 : 0
  bucket = "${var.project_name}-${var.environment}-${random_id.suffix[0].hex}"
  tags   = { Name = "${var.project_name}-${var.environment}" }
}

resource "random_id" "suffix" {
  count       = local.deploy_s3 ? 1 : 0
  byte_length = 4
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
