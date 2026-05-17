variable "environment" {
  description = "Deployment environment (dev | staging | prod)"
  type        = string
  default     = "dev"
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be dev, staging, or prod."
  }
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "ap-south-1"
}

variable "project_name" {
  description = "Project name prefix"
  type        = string
  default     = "myapp"
}

variable "enabled_services" {
  description = "Comma-separated services to deploy (vpc,ec2,rds,s3,iam,lambda,ecs)"
  type        = string
  default     = "vpc"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "existing_vpc_id" {
  type    = string
  default = ""
}

variable "existing_subnet_id" {
  type    = string
  default = ""
}

variable "ec2_instance_type" {
  type    = string
  default = "t3.micro"
}

variable "ec2_instance_count" {
  type    = number
  default = 1
}
