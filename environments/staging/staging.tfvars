# staging.tfvars
environment        = "staging"
region             = "us-east-1"
project_name       = "myapp"

ec2_instance_type  = "t3.small"
ec2_instance_count = 1
rds_instance_class = "db.t3.small"

vpc_cidr           = "10.1.0.0/16"
