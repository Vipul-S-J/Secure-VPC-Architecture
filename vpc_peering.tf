# This account's side of the VPC peerings. The other side (request + its routes) lives in the partner account.
# The accepter resource also adopts a peering that was already accepted in the console.

locals {
  peered_route_tables = {
    private = aws_route_table.private.id
    db      = aws_route_table.db.id
  }
}

# ---------------------------------------------------------------- Partner VPC

resource "aws_vpc_peering_connection_accepter" "partner" {
  count = local.partner_peering ? 1 : 0

  vpc_peering_connection_id = var.partner_peering_connection_id
  auto_accept               = true

  tags = { Name = "${local.name}-partner-peering" }
}

resource "aws_route" "to_partner" {
  for_each = local.partner_peering ? local.peered_route_tables : {}

  route_table_id            = each.value
  destination_cidr_block    = var.partner_vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection_accepter.partner[0].id
}

# ---------------------------------------------------------------- managed database provider VPC

resource "aws_vpc_peering_connection_accepter" "db_provider" {
  count = local.db_provider_peering ? 1 : 0

  vpc_peering_connection_id = var.db_provider_peering_connection_id
  auto_accept               = true

  tags = { Name = "${local.name}-db-provider-peering" }
}

resource "aws_route" "to_db_provider" {
  for_each = local.db_provider_peering ? local.peered_route_tables : {}

  route_table_id            = each.value
  destination_cidr_block    = var.db_provider_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection_accepter.db_provider[0].id
}
