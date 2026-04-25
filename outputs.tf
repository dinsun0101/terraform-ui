output "vpc_id" {
  description = "VPC ID"
  value       = length(module.vpc) > 0 ? module.vpc[0].vpc_id : null
}

output "ec2_instance_ids" {
  description = "EC2 instance IDs"
  value       = length(module.ec2) > 0 ? module.ec2[0].instance_ids : []
}

output "rds_endpoint" {
  description = "RDS endpoint"
  value       = length(module.rds) > 0 ? module.rds[0].endpoint : null
  sensitive   = true
}

output "s3_bucket_name" {
  description = "S3 bucket name"
  value       = length(module.s3) > 0 ? module.s3[0].bucket_name : null
}
