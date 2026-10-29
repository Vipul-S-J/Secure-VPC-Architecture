# CIDRs are passed in through variables and are not stored in this repo.
locals {
  public_subnets = {
    "1a" = { name = "${local.name}-public-1a", cidr = var.subnet_cidrs.public_1a, az = local.azs[0] }
    "1b" = { name = "${local.name}-public-1b", cidr = var.subnet_cidrs.public_1b, az = local.azs[1] }
  }
  private_subnets = {
    "1a" = { name = "${local.name}-private-1a", cidr = var.subnet_cidrs.private_1a, az = local.azs[0] }
    "1b" = { name = "${local.name}-private-1b", cidr = var.subnet_cidrs.private_1b, az = local.azs[1] }
  }
  db_subnets = {
    "1a" = { name = "${local.name}-db-1a", cidr = var.subnet_cidrs.db_1a, az = local.azs[0] }
    "1b" = { name = "${local.name}-db-1b", cidr = var.subnet_cidrs.db_1b, az = local.azs[1] }
  }
}

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "${local.name}-vpc" }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${local.name}-igw" }
}

# ---------------------------------------------------------------- Subnets

resource "aws_subnet" "public" {
  for_each = local.public_subnets

  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value.cidr
  availability_zone = each.value.az
  tags              = { Name = each.value.name, Tier = "public" }
}

resource "aws_subnet" "private" {
  for_each = local.private_subnets

  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value.cidr
  availability_zone = each.value.az
  tags              = { Name = each.value.name, Tier = "private" }
}

resource "aws_subnet" "db" {
  for_each = local.db_subnets

  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value.cidr
  availability_zone = each.value.az
  tags              = { Name = each.value.name, Tier = "db" }
}

# ---------------------------------------------------------------- NAT gateway (public subnet 1a)

resource "aws_eip" "nat" {
  domain = "vpc"
  tags   = { Name = "${local.name}-nat-eip" }
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public["1a"].id
  tags          = { Name = "${local.name}-nat" }

  depends_on = [aws_internet_gateway.main]
}

# ---------------------------------------------------------------- Route tables

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${local.name}-public-rt" }
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id
}

# Private route table with the NAT gateway.
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${local.name}-private-rt" }
}

resource "aws_route" "private_nat" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.main.id
}

# DB subnets have no internet route. Only VPC-local and peering traffic.
resource "aws_route_table" "db" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${local.name}-db-rt" }
}

resource "aws_route_table_association" "public" {
  for_each       = aws_subnet.public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  for_each       = aws_subnet.private
  subnet_id      = each.value.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "db" {
  for_each       = aws_subnet.db
  subnet_id      = each.value.id
  route_table_id = aws_route_table.db.id
}
