# Regional EFS for the app servers, with a mount target in each private subnet.
resource "aws_efs_file_system" "app" {
  creation_token   = "${local.name}-efs"
  encrypted        = true
  kms_key_id       = aws_kms_key.prod.arn
  performance_mode = "generalPurpose"
  throughput_mode  = "elastic"

  lifecycle_policy {
    transition_to_ia = "AFTER_30_DAYS"
  }

  tags = { Name = "${local.name}-efs" }
}

resource "aws_efs_backup_policy" "app" {
  file_system_id = aws_efs_file_system.app.id
  backup_policy {
    status = "ENABLED"
  }
}

resource "aws_efs_mount_target" "app" {
  for_each = aws_subnet.private

  file_system_id  = aws_efs_file_system.app.id
  subnet_id       = each.value.id
  security_groups = [aws_security_group.efs.id]
}
