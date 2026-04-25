# prod.tfvars
environment        = "prod"
region             = "ap-south-1"
project_name       = "myapp"

ec2_instance_type  = "t3.medium"
ec2_instance_count = 2
rds_instance_class = "db.t3.medium"

vpc_cidr           = "10.2.0.0/16"
