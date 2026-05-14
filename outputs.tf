output "vpc_id" {
  value = length(aws_vpc.main) > 0 ? aws_vpc.main[0].id : null
}

output "public_subnet_ids" {
  value = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  value = aws_subnet.private[*].id
}

output "ec2_instance_ids" {
  value = aws_instance.web[*].id
}

output "s3_bucket_name" {
  value = length(aws_s3_bucket.main) > 0 ? aws_s3_bucket.main[0].bucket : null
}

output "ecs_cluster_name" {
  value = length(aws_ecs_cluster.main) > 0 ? aws_ecs_cluster.main[0].name : null
}

output "iam_role_arn" {
  value = length(aws_iam_role.app) > 0 ? aws_iam_role.app[0].arn : null
}
