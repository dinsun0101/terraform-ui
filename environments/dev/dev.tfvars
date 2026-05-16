# dev.tfvars — values for the dev environment
environment        = "dev"
region             = "ap-south-1"
project_name       = "myapp"

# Instance sizing — small for dev
ec2_instance_type  = "t3.micro"
ec2_instance_count = 1
rds_instance_class = "db.t3.micro"

vpc_cidr           = "10.0.0.0/16"

