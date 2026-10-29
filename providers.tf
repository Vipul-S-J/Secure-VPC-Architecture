provider "aws" {
  region              = var.region
  allowed_account_ids = [var.hmd_account_id]

  default_tags {
    tags = {
      Project     = var.project
      Environment = var.environment
      Account     = "HMD"
      ManagedBy   = "Terraform"
    }
  }
}
