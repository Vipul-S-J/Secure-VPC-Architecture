# App server in private subnet 1a, behind the ALB.
resource "aws_instance" "app" {
  ami                    = local.app_ami_id
  instance_type          = var.app_instance_type
  subnet_id              = aws_subnet.private["1a"].id
  vpc_security_group_ids = [aws_security_group.app.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_basic.name
  user_data              = file("${path.module}/user_data/app-server.sh")

  # No key pair. Access is through SSM Session Manager.

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

  tags        = { Name = "${local.name}-app" }
  volume_tags = { Name = "${local.name}-app-root" }

  lifecycle {
    # A newer Amazon Linux AMI must not replace the running server.
    ignore_changes = [ami, user_data]
  }
}

# Base AMI, taken from the app server once it is set up.
resource "aws_ami_from_instance" "base" {
  count = var.create_base_ami ? 1 : 0

  name                    = "${local.name}-base-ami"
  source_instance_id      = aws_instance.app.id
  snapshot_without_reboot = true

  tags = { Name = "${local.name}-base-ami" }
}
