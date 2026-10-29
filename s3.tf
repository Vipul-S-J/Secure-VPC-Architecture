# S3 bucket for user static data (private, KMS-encrypted, versioned).
resource "aws_s3_bucket" "user_static" {
  bucket = var.user_static_bucket_name
  tags   = { Name = var.user_static_bucket_name }
}

resource "aws_s3_bucket_ownership_controls" "user_static" {
  bucket = aws_s3_bucket.user_static.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_public_access_block" "user_static" {
  bucket                  = aws_s3_bucket.user_static.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "user_static" {
  bucket = aws_s3_bucket.user_static.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "user_static" {
  bucket = aws_s3_bucket.user_static.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.prod.arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_policy" "user_static" {
  bucket = aws_s3_bucket.user_static.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "DenyInsecureTransport"
      Effect    = "Deny"
      Principal = "*"
      Action    = "s3:*"
      Resource  = [aws_s3_bucket.user_static.arn, "${aws_s3_bucket.user_static.arn}/*"]
      Condition = { Bool = { "aws:SecureTransport" = "false" } }
    }]
  })

  depends_on = [aws_s3_bucket_public_access_block.user_static]
}
