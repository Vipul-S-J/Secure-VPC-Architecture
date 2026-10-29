# Single-region symmetric key (encrypt/decrypt), used for CloudTrail, CloudWatch Logs,
# EBS, EFS, RDS, S3 and SNS.
resource "aws_kms_key" "prod" {
  description             = "kh_hmd prod key (eu-north-1)"
  key_usage               = "ENCRYPT_DECRYPT"
  multi_region            = false
  enable_key_rotation     = true
  deletion_window_in_days = 30
  policy                  = data.aws_iam_policy_document.kms.json

  tags = { Name = "kh_hmd-prod-eu-key" }
}

resource "aws_kms_alias" "prod" {
  name          = "alias/kh_hmd-prod-eu-key"
  target_key_id = aws_kms_key.prod.key_id
}

data "aws_iam_policy_document" "kms" {
  # IAM policies in this account control access (EBS, EFS, RDS, S3 use this path).
  statement {
    sid       = "AccountRoot"
    actions   = ["kms:*"]
    resources = ["*"]
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${local.account_id}:root"]
    }
  }

  statement {
    sid       = "CloudTrailEncrypt"
    actions   = ["kms:GenerateDataKey*"]
    resources = ["*"]
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"
      values   = [local.trail_arn]
    }
    condition {
      test     = "StringLike"
      variable = "kms:EncryptionContext:aws:cloudtrail:arn"
      values   = ["arn:aws:cloudtrail:*:${local.account_id}:trail/*"]
    }
  }

  statement {
    sid       = "CloudTrailDescribe"
    actions   = ["kms:DescribeKey"]
    resources = ["*"]
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
  }

  statement {
    sid = "CloudWatchLogs"
    actions = [
      "kms:Encrypt*",
      "kms:Decrypt*",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:Describe*",
    ]
    resources = ["*"]
    principals {
      type        = "Service"
      identifiers = ["logs.${var.region}.amazonaws.com"]
    }
    condition {
      test     = "ArnLike"
      variable = "kms:EncryptionContext:aws:logs:arn"
      values   = ["arn:aws:logs:${var.region}:${local.account_id}:log-group:*"]
    }
  }

  # CloudWatch alarms and EventBridge publish to the encrypted SNS topic.
  statement {
    sid       = "AlarmsAndEventsToSns"
    actions   = ["kms:Decrypt", "kms:GenerateDataKey*"]
    resources = ["*"]
    principals {
      type        = "Service"
      identifiers = ["cloudwatch.amazonaws.com", "events.amazonaws.com"]
    }
  }
}
