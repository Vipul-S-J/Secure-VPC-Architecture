data "aws_caller_identity" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  azs        = ["${var.region}a", "${var.region}b"]

  # Names from the architecture document.
  trail_name    = "kh_hmd-eu-pd-cloudtrail"
  trail_arn     = "arn:aws:cloudtrail:${var.region}:${local.account_id}:trail/${local.trail_name}"
  https_enabled = var.certificate_arn != ""
  kaha_peering  = var.kaha_peering_connection_id != ""
  atlas_peering = var.atlas_peering_connection_id != ""
  app_ami_id    = var.app_ami_id != "" ? var.app_ami_id : data.aws_ssm_parameter.al2023.insecure_value
  openvpn_count = var.create_openvpn ? 1 : 0
}

# Latest Amazon Linux 2023 (x86_64). Used when app_ami_id is not set.
data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}
