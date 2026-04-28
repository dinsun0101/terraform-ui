##############################################################################
#  TerraConsole — Root Terraform Configuration
#  Services are toggled on/off via the `enabled_services` variable,
#  which is passed in as a comma-separated string from GitHub Actions.
##############################################################################

terraform {
  required_version = ">= 1.7.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # S3 backend — update bucket/region to match your setup
  backend "s3" {
    bucket         = "terraform-ui-tfstate"    # ← change this
    key            = "dev/terraform.tfstate"           # overridden by -backend-config in CI
    region         = "ap-south-1"                     # ← change this
    encrypt        = true
    #dynamodb_table = "terraform-state-lock"           # optional, for state locking
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Environment  = var.environment
      ManagedBy    = "terraform"
      DeployedVia  = "terra-console"
      Project      = "myapp"
    }
  }
}

# ── Service toggles ────────────────────────────────────────────────────────
# Convert comma-separated string to a set for easy lookup
locals {
  services = toset(split(",", var.enabled_services))

  deploy_vpc    = contains(local.services, "vpc")
  deploy_ec2    = contains(local.services, "ec2")
  deploy_rds    = contains(local.services, "rds")
  deploy_s3     = contains(local.services, "s3")
  deploy_iam    = contains(local.services, "iam")
  deploy_lambda = contains(local.services, "lambda")
  deploy_ecs    = contains(local.services, "ecs")
}

# ── VPC ────────────────────────────────────────────────────────────────────
module "vpc" {
  count  = local.deploy_vpc ? 1 : 0
  source = "./modules/vpc"

  environment = var.environment
  region      = var.region
  cidr_block  = var.vpc_cidr
}

# ── EC2 ────────────────────────────────────────────────────────────────────
module "ec2" {
  count  = local.deploy_ec2 ? 1 : 0
  source = "./modules/ec2"

  environment    = var.environment
  vpc_id         = local.deploy_vpc ? module.vpc[0].vpc_id : var.existing_vpc_id
  subnet_ids     = local.deploy_vpc ? module.vpc[0].public_subnet_ids : var.existing_subnet_ids
  instance_type  = var.ec2_instance_type
  instance_count = var.ec2_instance_count

  depends_on = [module.vpc]
}

# ── RDS ────────────────────────────────────────────────────────────────────
module "rds" {
  count  = local.deploy_rds ? 1 : 0
  source = "./modules/rds"

  environment    = var.environment
  vpc_id         = local.deploy_vpc ? module.vpc[0].vpc_id : var.existing_vpc_id
  subnet_ids     = local.deploy_vpc ? module.vpc[0].private_subnet_ids : var.existing_subnet_ids
  instance_class = var.rds_instance_class
  engine         = var.rds_engine
  db_name        = var.rds_db_name

  depends_on = [module.vpc]
}

# ── S3 ─────────────────────────────────────────────────────────────────────
module "s3" {
  count  = local.deploy_s3 ? 1 : 0
  source = "./modules/s3"

  environment = var.environment
  bucket_name = "hello-finalcheck-run01"
}

# ── IAM ────────────────────────────────────────────────────────────────────
module "iam" {
  count  = local.deploy_iam ? 1 : 0
  source = "./modules/iam"

  environment  = var.environment
  project_name = var.project_name
}

# ── Lambda ─────────────────────────────────────────────────────────────────
module "lambda" {
  count  = local.deploy_lambda ? 1 : 0
  source = "./modules/lambda"

  environment  = var.environment
  project_name = var.project_name
  vpc_id       = local.deploy_vpc ? module.vpc[0].vpc_id : var.existing_vpc_id
  subnet_ids   = local.deploy_vpc ? module.vpc[0].private_subnet_ids : var.existing_subnet_ids

  depends_on = [module.vpc, module.iam]
}

# ── ECS ────────────────────────────────────────────────────────────────────
module "ecs" {
  count  = local.deploy_ecs ? 1 : 0
  source = "./modules/ecs"

  environment  = var.environment
  project_name = var.project_name
  vpc_id       = local.deploy_vpc ? module.vpc[0].vpc_id : var.existing_vpc_id
  subnet_ids   = local.deploy_vpc ? module.vpc[0].private_subnet_ids : var.existing_subnet_ids

  depends_on = [module.vpc]
}
