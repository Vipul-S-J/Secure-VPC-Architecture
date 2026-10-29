variable "hmd_account_id" {
  description = "HMD AWS account ID. Terraform refuses to run against any other account."
  type        = string
}

variable "project" {
  description = "Short project name used as the first part of every resource name."
  type        = string
  default     = "app"

  validation {
    condition     = can(regex("^[a-z0-9-]{1,12}$", var.project))
    error_message = "Use 1-12 lowercase letters, digits or hyphens (S3, RDS and ALB naming rules)."
  }
}

variable "environment" {
  description = "Environment name used in every resource name."
  type        = string
  default     = "prod"

  validation {
    condition     = can(regex("^[a-z0-9]{1,8}$", var.environment))
    error_message = "Use 1-8 lowercase letters or digits."
  }
}

variable "region" {
  description = "AWS region (Europe - Stockholm)."
  type        = string
  default     = "eu-north-1"
}

# ---------------------------------------------------------------- Network

variable "vpc_cidr" {
  description = "CIDR of the VPC."
  type        = string
}

variable "subnet_cidrs" {
  description = "CIDRs of the six subnets (public, private app and private DB, in AZ a and b)."
  type = object({
    public_1a  = string
    public_1b  = string
    private_1a = string
    private_1b = string
    db_1a      = string
    db_1b      = string
  })
}

# ---------------------------------------------------------------- VPC peering

variable "kaha_peering_connection_id" {
  description = "ID (pcx-...) of the VPC peering connection requested from the KaHa account. Leave empty to skip."
  type        = string
  default     = ""

  validation {
    condition     = var.kaha_peering_connection_id == "" || var.kaha_vpc_cidr != ""
    error_message = "Set kaha_vpc_cidr when kaha_peering_connection_id is set."
  }
}

variable "kaha_vpc_cidr" {
  description = "CIDR of the KaHa VPC. Used for routes and for MySQL access from KaHa app servers."
  type        = string
  default     = ""
}

variable "atlas_peering_connection_id" {
  description = "ID (pcx-...) of the peering connection requested from MongoDB Atlas. Leave empty to skip."
  type        = string
  default     = ""

  validation {
    condition     = var.atlas_peering_connection_id == "" || var.atlas_cidr != ""
    error_message = "Set atlas_cidr when atlas_peering_connection_id is set."
  }
}

variable "atlas_cidr" {
  description = "CIDR of the MongoDB Atlas project VPC."
  type        = string
  default     = ""
}

# ---------------------------------------------------------------- Load balancer

variable "certificate_arn" {
  description = "ACM certificate ARN (eu-north-1) for the HTTPS listener. Empty = HTTP only."
  type        = string
  default     = ""
}

variable "app_port" {
  description = "Port the application listens on behind the ALB."
  type        = number
  default     = 80
}

variable "health_check_path" {
  description = "ALB target group health check path."
  type        = string
  default     = "/"
}

# ---------------------------------------------------------------- App server

variable "app_instance_type" {
  description = "Instance type of the app server."
  type        = string
  default     = "t3a.micro"
}

variable "app_ami_id" {
  description = "AMI for the app server, e.g. the base AMI. Empty = latest Amazon Linux 2023."
  type        = string
  default     = ""
}

variable "create_base_ami" {
  description = "Create the base AMI from the app server. Enable after user data has finished."
  type        = bool
  default     = false
}

# ---------------------------------------------------------------- RDS MySQL

variable "db_engine_version" {
  description = "RDS MySQL major version. 8.0 left standard support on 31 July 2026."
  type        = string
  default     = "8.4"
}

variable "db_instance_class" {
  type    = string
  default = "db.t4g.micro"
}

variable "db_allocated_storage" {
  description = "Initial storage in GB."
  type        = number
  default     = 20
}

variable "db_max_allocated_storage" {
  description = "Storage autoscaling limit in GB."
  type        = number
  default     = 100
}

variable "db_multi_az" {
  type    = bool
  default = true
}

variable "db_name" {
  type    = string
  default = "hmd"
}

variable "db_username" {
  description = "Master user. The password is generated and stored in Secrets Manager by RDS."
  type        = string
  default     = "admin"
}

# ---------------------------------------------------------------- S3 / logging

variable "user_static_bucket_name" {
  description = "S3 bucket for user static data."
  type        = string
}

variable "cloudtrail_bucket_name" {
  description = "S3 bucket that stores CloudTrail logs."
  type        = string
}

variable "config_bucket_name" {
  description = "S3 bucket that stores AWS Config snapshots."
  type        = string
}

variable "log_retention_days" {
  description = "Retention for CloudWatch log groups."
  type        = number
  default     = 365
}

variable "alert_emails" {
  description = "Email addresses subscribed to the alerts SNS topic."
  type        = list(string)
  default     = []
}

# ---------------------------------------------------------------- OpenVPN

variable "create_openvpn" {
  type    = bool
  default = true
}

variable "openvpn_ami_id" {
  description = "AMI for the OpenVPN server, e.g. OpenVPN Access Server from AWS Marketplace (eu-north-1)."
  type        = string
  default     = ""
}

variable "openvpn_instance_type" {
  type    = string
  default = "t3a.small"
}

variable "openvpn_key_name" {
  description = "Optional EC2 key pair for the OpenVPN server. SSM Session Manager works without it."
  type        = string
  default     = null
}

variable "vpn_client_cidrs" {
  description = "CIDRs allowed to connect to the VPN (UDP 1194, TCP 443)."
  type        = list(string)
  default     = []
}

variable "vpn_admin_cidrs" {
  description = "CIDRs allowed to reach the OpenVPN admin UI (TCP 943)."
  type        = list(string)
  default     = []
}
