# OpenVPN server in public subnet 1a. KaHa DevOps connect through it to reach the HMD VPC.
resource "aws_instance" "openvpn" {
  count = local.openvpn_count

  ami                    = var.openvpn_ami_id
  instance_type          = var.openvpn_instance_type
  subnet_id              = aws_subnet.public["1a"].id
  vpc_security_group_ids = [aws_security_group.openvpn[0].id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_basic.name
  key_name               = var.openvpn_key_name
  source_dest_check      = false

  metadata_options {
    http_tokens   = "required"
    http_endpoint = "enabled"
  }

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
    encrypted   = true
    kms_key_id  = aws_kms_key.prod.arn
  }

  tags        = { Name = "${local.name}-openvpn" }
  volume_tags = { Name = "${local.name}-openvpn-root" }

  lifecycle {
    ignore_changes = [ami]

    precondition {
      condition     = var.openvpn_ami_id != ""
      error_message = "Set openvpn_ami_id (e.g. OpenVPN Access Server AMI for eu-north-1), or set create_openvpn = false."
    }
  }
}

resource "aws_eip" "openvpn" {
  count = local.openvpn_count

  domain   = "vpc"
  instance = aws_instance.openvpn[0].id
  tags     = { Name = "${local.name}-openvpn-eip" }

  depends_on = [aws_internet_gateway.main]
}
