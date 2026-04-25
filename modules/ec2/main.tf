variable "environment"    {}
variable "vpc_id"         {}
variable "subnet_ids"     { type = list(string) }
variable "instance_type"  { default = "t3.micro" }
variable "instance_count" { default = 1 }

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

resource "aws_security_group" "web" {
  name        = "${var.environment}-web-sg"
  description = "Web server security group — managed by terraform"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.environment}-web-sg" }
}

resource "aws_instance" "web" {
  count                  = var.instance_count
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_ids[count.index % length(var.subnet_ids)]
  vpc_security_group_ids = [aws_security_group.web.id]

  tags = { Name = "${var.environment}-web-${count.index + 1}" }
}

output "instance_ids"  { value = aws_instance.web[*].id }
output "private_ips"   { value = aws_instance.web[*].private_ip }
output "sg_id"         { value = aws_security_group.web.id }
