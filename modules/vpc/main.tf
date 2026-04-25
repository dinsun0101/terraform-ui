variable "environment" {}
variable "region" {}
variable "cidr_block" { default = "10.0.0.0/16" }

data "aws_availability_zones" "available" { state = "available" }

locals {
  azs             = slice(data.aws_availability_zones.available.names, 0, 2)
  public_cidrs    = [for i, az in local.azs : cidrsubnet(var.cidr_block, 8, i)]
  private_cidrs   = [for i, az in local.azs : cidrsubnet(var.cidr_block, 8, i + 10)]
}

resource "aws_vpc" "main" {
  cidr_block           = var.cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = { Name = "${var.environment}-vpc" }
}

resource "aws_subnet" "public" {
  count             = length(local.azs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = local.public_cidrs[count.index]
  availability_zone = local.azs[count.index]
  map_public_ip_on_launch = true
  tags = { Name = "${var.environment}-public-${count.index + 1}", Tier = "public" }
}

resource "aws_subnet" "private" {
  count             = length(local.azs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = local.private_cidrs[count.index]
  availability_zone = local.azs[count.index]
  tags = { Name = "${var.environment}-private-${count.index + 1}", Tier = "private" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${var.environment}-igw" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = { Name = "${var.environment}-public-rt" }
}

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

output "vpc_id"             { value = aws_vpc.main.id }
output "public_subnet_ids"  { value = aws_subnet.public[*].id }
output "private_subnet_ids" { value = aws_subnet.private[*].id }
