output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_subnet_ids" {
  value = { for k, s in aws_subnet.public : k => s.id }
}

output "private_subnet_ids" {
  value = { for k, s in aws_subnet.private : k => s.id }
}

output "db_subnet_ids" {
  value = { for k, s in aws_subnet.db : k => s.id }
}

output "nat_public_ip" {
  description = "Outbound IP of the private subnets. Whitelist this at external providers."
  value       = aws_eip.nat.public_ip
}

output "alb_dns_name" {
  value = aws_lb.main.dns_name
}

output "app_instance_id" {
  value = aws_instance.app.id
}

output "efs_id" {
  value = aws_efs_file_system.app.id
}

output "efs_dns_name" {
  value = aws_efs_file_system.app.dns_name
}

output "rds_endpoint" {
  value = aws_db_instance.mysql.endpoint
}

output "rds_master_secret_arn" {
  description = "Secrets Manager secret holding the MySQL master password."
  value       = aws_db_instance.mysql.master_user_secret[0].secret_arn
}

output "kms_key_arn" {
  value = aws_kms_key.prod.arn
}

output "user_static_bucket" {
  value = aws_s3_bucket.user_static.id
}

output "alerts_topic_arn" {
  value = aws_sns_topic.alerts.arn
}

output "openvpn_public_ip" {
  value = var.create_openvpn ? aws_eip.openvpn[0].public_ip : null
}
