output "vpc_id" {
  description = "VPC ID"
  value       = length(aws_vpc.main) > 0 ? aws_vpc.main[0].id : null
}

output "ec2_instance_ids" {
  description = "EC2 instance IDs"
  value       = aws_instance.web[*].id
}

output "s3_bucket_name" {
  description = "S3 bucket name"
  value       = length(aws_s3_bucket.main) > 0 ? aws_s3_bucket.main[0].bucket : null
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = aws_subnet.private[*].id
}
