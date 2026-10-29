# Default SG of the VPC: remove all rules so nothing uses it by accident.
resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${local.name}-default-sg-unused" }
}

# ---------------------------------------------------------------- ALB

resource "aws_security_group" "alb" {
  name        = "${local.name}-alb-sg"
  description = "Internet-facing ALB: HTTP/HTTPS from anywhere"
  vpc_id      = aws_vpc.main.id
  tags        = { Name = "${local.name}-alb-sg" }
}

resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id
  description       = "HTTP from internet"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "alb_https" {
  security_group_id = aws_security_group.alb.id
  description       = "HTTPS from internet"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "alb_to_app" {
  security_group_id            = aws_security_group.alb.id
  description                  = "To app servers"
  ip_protocol                  = "tcp"
  from_port                    = var.app_port
  to_port                      = var.app_port
  referenced_security_group_id = aws_security_group.app.id
}

# ---------------------------------------------------------------- App servers

resource "aws_security_group" "app" {
  name        = "${local.name}-app-sg"
  description = "App servers: traffic only from the ALB"
  vpc_id      = aws_vpc.main.id
  tags        = { Name = "${local.name}-app-sg" }
}

resource "aws_vpc_security_group_ingress_rule" "app_from_alb" {
  security_group_id            = aws_security_group.app.id
  description                  = "App port from ALB"
  ip_protocol                  = "tcp"
  from_port                    = var.app_port
  to_port                      = var.app_port
  referenced_security_group_id = aws_security_group.alb.id
}

resource "aws_vpc_security_group_egress_rule" "app_all" {
  security_group_id = aws_security_group.app.id
  description       = "Outbound via NAT (packages, SSM, CloudWatch, external APIs)"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# ---------------------------------------------------------------- EFS

resource "aws_security_group" "efs" {
  name        = "${local.name}-efs-sg"
  description = "EFS mount targets: NFS from app servers"
  vpc_id      = aws_vpc.main.id
  tags        = { Name = "${local.name}-efs-sg" }
}

resource "aws_vpc_security_group_ingress_rule" "efs_from_app" {
  security_group_id            = aws_security_group.efs.id
  description                  = "NFS from app servers"
  ip_protocol                  = "tcp"
  from_port                    = 2049
  to_port                      = 2049
  referenced_security_group_id = aws_security_group.app.id
}

# ---------------------------------------------------------------- RDS MySQL

resource "aws_security_group" "db" {
  name        = "${local.name}-db-sg"
  description = "RDS MySQL: only from the app layer, partner VPC and OpenVPN"
  vpc_id      = aws_vpc.main.id
  tags        = { Name = "${local.name}-db-sg" }
}

resource "aws_vpc_security_group_ingress_rule" "db_from_app" {
  security_group_id            = aws_security_group.db.id
  description                  = "MySQL from app servers"
  ip_protocol                  = "tcp"
  from_port                    = 3306
  to_port                      = 3306
  referenced_security_group_id = aws_security_group.app.id
}

resource "aws_vpc_security_group_ingress_rule" "db_from_partner" {
  count = local.partner_peering ? 1 : 0

  security_group_id = aws_security_group.db.id
  description       = "MySQL from partner VPC over peering"
  ip_protocol       = "tcp"
  from_port         = 3306
  to_port           = 3306
  cidr_ipv4         = var.partner_vpc_cidr
}

resource "aws_vpc_security_group_ingress_rule" "db_from_openvpn" {
  count = local.openvpn_count

  security_group_id            = aws_security_group.db.id
  description                  = "MySQL from DevOps over OpenVPN"
  ip_protocol                  = "tcp"
  from_port                    = 3306
  to_port                      = 3306
  referenced_security_group_id = aws_security_group.openvpn[0].id
}

# ---------------------------------------------------------------- OpenVPN

locals {
  vpn_client_ports = [
    { proto = "udp", port = 1194 },
    { proto = "tcp", port = 443 },
  ]
  vpn_client_rules = var.create_openvpn ? {
    for pair in setproduct(var.vpn_client_cidrs, local.vpn_client_ports) :
    "${pair[1].proto}-${pair[1].port}-${pair[0]}" => { cidr = pair[0], proto = pair[1].proto, port = pair[1].port }
  } : {}
  vpn_admin_rules = var.create_openvpn ? toset(var.vpn_admin_cidrs) : toset([])
}

resource "aws_security_group" "openvpn" {
  count = local.openvpn_count

  name        = "${local.name}-openvpn-sg"
  description = "OpenVPN server for the DevOps team"
  vpc_id      = aws_vpc.main.id
  tags        = { Name = "${local.name}-openvpn-sg" }
}

resource "aws_vpc_security_group_ingress_rule" "openvpn_clients" {
  for_each = local.vpn_client_rules

  security_group_id = aws_security_group.openvpn[0].id
  description       = "VPN clients ${upper(each.value.proto)} ${each.value.port}"
  ip_protocol       = each.value.proto
  from_port         = each.value.port
  to_port           = each.value.port
  cidr_ipv4         = each.value.cidr
}

resource "aws_vpc_security_group_ingress_rule" "openvpn_admin" {
  for_each = local.vpn_admin_rules

  security_group_id = aws_security_group.openvpn[0].id
  description       = "OpenVPN admin UI"
  ip_protocol       = "tcp"
  from_port         = 943
  to_port           = 943
  cidr_ipv4         = each.value
}

resource "aws_vpc_security_group_egress_rule" "openvpn_all" {
  count = local.openvpn_count

  security_group_id = aws_security_group.openvpn[0].id
  description       = "Outbound to VPC, peered VPCs and internet"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}
