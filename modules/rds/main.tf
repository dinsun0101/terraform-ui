variable "environment"    {}
variable "vpc_id"         {}
variable "subnet_ids"     { type = list(string) }
variable "instance_class" { default = "db.t3.micro" }
variable "engine"         { default = "postgres" }
variable "db_name"        { default = "appdb" }

resource "aws_db_subnet_group" "main" {
  name       = "${var.environment}-db-subnet-group"
  subnet_ids = var.subnet_ids
  tags       = { Name = "${var.environment}-db-subnet-group" }
}

resource "aws_security_group" "rds" {
  name        = "${var.environment}-rds-sg"
  description = "RDS security group — managed by terraform"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.environment}-rds-sg" }
}

resource "aws_db_instance" "main" {
  identifier        = "${var.environment}-${var.engine}"
  engine            = var.engine
  engine_version    = var.engine == "postgres" ? "15.4" : "8.0"
  instance_class    = var.instance_class
  allocated_storage = var.environment == "prod" ? 100 : 20
  db_name           = var.db_name
  username          = "admin"
  password          = random_password.db.result

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  backup_retention_period = var.environment == "prod" ? 7 : 1
  deletion_protection     = var.environment == "prod"
  skip_final_snapshot     = var.environment != "prod"
  multi_az                = var.environment == "prod"

  tags = { Name = "${var.environment}-${var.engine}" }
}

resource "random_password" "db" {
  length  = 24
  special = false
}

resource "aws_ssm_parameter" "db_password" {
  name  = "/${var.environment}/db/password"
  type  = "SecureString"
  value = random_password.db.result
  tags  = { Name = "${var.environment}-db-password" }
}

output "endpoint"       { value     = aws_db_instance.main.endpoint }
output "db_name"        { value     = aws_db_instance.main.db_name }
output "password_param" { value     = aws_ssm_parameter.db_password.name }
