locals {
  public_subnets = {
    "1a" = { name = "kh_hmd-pd-1a-pub-subnet", cidr = "10.91.0.0/23", az = local.azs[0] }
    "1b" = { name = "kh_hmd-pd-1b-pub-subnet", cidr = "10.91.2.0/23", az = local.azs[1] }
  }
  private_subnets = {
    "1a" = { name = "kh_hmd-pd-1a-pvt-subnet", cidr = "10.91.4.0/23", az = local.azs[0] }
    "1b" = { name = "kh_hmd-pd-1b-pvt-subnet", cidr = "10.91.6.0/23", az = local.azs[1] }
  }
  db_subnets = {
    "1a" = { name = "kh_hmd-pd-db-1a-pvt-subnet", cidr = "10.91.8.0/23", az = local.azs[0] }
    "1b" = { name = "kh_hmd-pd-db-1b-pvt-subnet", cidr = "10.91.10.0/23", az = local.azs[1] }
  }
}

resource "aws_vpc" "main" {
  cidr_block           = "10.91.0.0/17"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "kh_hmd-eu-pd-vpc" }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "kh_hmd-eu-pd-igw" }
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
  tags   = { Name = "kh_hmd-eu-pd-pub-nat-eip" }
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public["1a"].id
  tags          = { Name = "kh_hmd-eu-pd-pub-nat" }

  depends_on = [aws_internet_gateway.main]
}

# ---------------------------------------------------------------- Route tables

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "kh_hmd-pd-pub-rtb" }
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id
}

# Private route table with the NAT gateway (kh_hmd-pd-pvt-rtb).
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "kh_hmd-pd-pvt-rtb" }
}

resource "aws_route" "private_nat" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.main.id
}

# DB subnets have no internet route. Only VPC-local and peering traffic.
resource "aws_route_table" "db" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "kh_hmd-pd-db-rtb" }
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
