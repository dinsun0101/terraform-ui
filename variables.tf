##############################################################################
#  Variables — all values with defaults; override via tfvars or CI inputs
##############################################################################

variable "environment" {
  description = "Deployment environment (dev | staging | prod)"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be dev, staging, or prod."
  }
}

variable "region" {
  description = "AWS region to deploy resources into"
  type        = string
  default     = "ap-south-1"
}

variable "project_name" {
  description = "Short project identifier used as a prefix in resource names"
  type        = string
  default     = "myapp"
}

variable "enabled_services" {
  description = "Comma-separated list of services to deploy (e.g. 'vpc,ec2,rds')"
  type        = string
  default     = "vpc"
}

# ── VPC ────────────────────────────────────────────────────────────────────
variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "vpc_id" {
  description = "Use an existing VPC instead of creating one (when vpc not in enabled_services)"
  type        = string
  default     = ""
}

variable "subnet_ids" {
  description = "Existing subnet IDs to use when not deploying a new VPC"
  type        = list(string)
  default     = []
}

# ── EC2 ────────────────────────────────────────────────────────────────────
variable "ec2_instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "ec2_instance_count" {
  description = "Number of EC2 instances to launch"
  type        = number
  default     = 1
}

# ── RDS ────────────────────────────────────────────────────────────────────
variable "rds_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "rds_engine" {
  description = "RDS database engine"
  type        = string
  default     = "postgres"
}

variable "rds_db_name" {
  description = "Initial database name"
  type        = string
  default     = "appdb"
}
