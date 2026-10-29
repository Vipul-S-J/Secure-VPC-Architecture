# HMD side of the VPC peerings. The KaHa side (request + KaHa routes) lives in the KaHa account.
# The accepter resource also adopts a peering that was already accepted in the console.

locals {
  peered_route_tables = {
    private = aws_route_table.private.id
    db      = aws_route_table.db.id
  }
}

# ---------------------------------------------------------------- KaHa VPC

resource "aws_vpc_peering_connection_accepter" "kaha" {
  count = local.kaha_peering ? 1 : 0

  vpc_peering_connection_id = var.kaha_peering_connection_id
  auto_accept               = true

  tags = { Name = "${local.name}-kaha-peering" }
}

resource "aws_route" "to_kaha" {
  for_each = local.kaha_peering ? local.peered_route_tables : {}

  route_table_id            = each.value
  destination_cidr_block    = var.kaha_vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection_accepter.kaha[0].id
}

# ---------------------------------------------------------------- MongoDB Atlas VPC

resource "aws_vpc_peering_connection_accepter" "atlas" {
  count = local.atlas_peering ? 1 : 0

  vpc_peering_connection_id = var.atlas_peering_connection_id
  auto_accept               = true

  tags = { Name = "${local.name}-atlas-peering" }
}

resource "aws_route" "to_atlas" {
  for_each = local.atlas_peering ? local.peered_route_tables : {}

  route_table_id            = each.value
  destination_cidr_block    = var.atlas_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection_accepter.atlas[0].id
}
