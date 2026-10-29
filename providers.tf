provider "aws" {
  region              = var.region
  allowed_account_ids = [var.hmd_account_id]

  default_tags {
    tags = {
      Project     = "kh_hmd"
      Environment = "prod"
      Account     = "HMD"
      ManagedBy   = "Terraform"
    }
  }
}
