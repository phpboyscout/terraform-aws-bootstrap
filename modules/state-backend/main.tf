# ----------------------------------------------------------------------
# state-backend — S3 bucket + customer-managed KMS CMK for OpenTofu /
# Terraform remote state. Hand-rolled (not via terraform-aws-modules) so
# we can keep `lifecycle { prevent_destroy = true }` on the bucket.
#
# Uses S3-native locking (`use_lockfile = true` in the consuming stack's
# backend config). No DynamoDB lock table needed.
# ----------------------------------------------------------------------

locals {
  kms_alias = coalesce(var.kms_alias, var.name)

  # Component tag added on top of the caller-supplied set. Caller wins
  # if they also pass a `Component` key (rare).
  tags = merge({ Component = "state-backend" }, var.tags)
}

# ---------- KMS key -----------------------------------------------------

resource "aws_kms_key" "this" {
  description             = "CMK encrypting OpenTofu state in s3://${var.name}"
  enable_key_rotation     = var.kms_enable_key_rotation
  deletion_window_in_days = var.kms_deletion_window_in_days
  policy                  = data.aws_iam_policy_document.kms.json
  tags                    = local.tags
}

resource "aws_kms_alias" "this" {
  name          = "alias/${local.kms_alias}"
  target_key_id = aws_kms_key.this.key_id
}

data "aws_iam_policy_document" "kms" {
  # checkov:skip=CKV_AWS_111:kms:* on the CMK for the account root is the AWS-documented pattern; narrowing it risks an unrecoverable lockout from the key. See https://docs.aws.amazon.com/kms/latest/developerguide/key-policy-default.html
  # checkov:skip=CKV_AWS_109:Same as CKV_AWS_111 — root account requires full control of the CMK.
  # checkov:skip=CKV_AWS_356:kms:* with Resource:* on the key itself is the only way to express "root has full control"; the policy IS the key.
  statement {
    sid    = "AllowAccountRootAdmin"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${var.account_id}:root"]
    }
    actions   = ["kms:*"]
    resources = ["*"]
  }
}

# ---------- S3 bucket ---------------------------------------------------

resource "aws_s3_bucket" "this" {
  # checkov:skip=CKV_AWS_18:Bucket access logging is a downstream concern. Callers wire CloudTrail S3 data events for this bucket in their security-baseline stack — bucket-level access logs would duplicate that record.
  # checkov:skip=CKV_AWS_144:Cross-region replication is unnecessary for a state bucket. The bucket is small, append-only via tofu, and versioning provides recovery. Multi-region DR is a separate concern outside bootstrap.
  # checkov:skip=CKV2_AWS_62:Event notifications add no value here — there is no consumer; auditing comes from CloudTrail, lifecycle from the lifecycle rules.
  bucket        = var.name
  force_destroy = var.force_destroy
  tags          = local.tags

  # Hard floor: a `tofu destroy` against the consuming stack must not
  # take state with it. Recovering from a deleted state bucket is
  # painful enough that the foot-gun is worth preventing in code. To
  # actually destroy, the caller does `tofu state rm` against the
  # bucket resource first.
  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.this.arn
    }
    # Bucket key — derive a per-bucket data key once per refresh,
    # cuts per-object KMS API calls by >99% for the state-read pattern.
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "this" {
  bucket                  = aws_s3_bucket.this.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "this" {
  bucket = aws_s3_bucket.this.id
  rule {
    object_ownership = "BucketOwnerEnforced" # ACLs disabled entirely.
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    id     = "abort-incomplete-multipart-uploads"
    status = "Enabled"

    filter {}

    abort_incomplete_multipart_upload {
      days_after_initiation = var.abort_incomplete_multipart_upload_days
    }
  }

  rule {
    id     = "transition-noncurrent-versions"
    status = "Enabled"

    filter {}

    dynamic "noncurrent_version_transition" {
      for_each = var.noncurrent_version_transitions
      content {
        noncurrent_days = noncurrent_version_transition.value.days
        storage_class   = noncurrent_version_transition.value.storage_class
      }
    }
  }
}

# Belt-and-braces bucket policy: refuse non-TLS, refuse PutObject that
# isn't SSE-KMS, refuse PutObject that uses a different KMS key. The
# default SSE config above also enforces SSE-KMS, but a client could
# override that with `x-amz-server-side-encryption: AES256` — this
# policy stops them.
resource "aws_s3_bucket_policy" "this" {
  bucket = aws_s3_bucket.this.id
  policy = data.aws_iam_policy_document.bucket.json
}

data "aws_iam_policy_document" "bucket" {
  statement {
    sid    = "DenyInsecureTransport"
    effect = "Deny"
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    actions = ["s3:*"]
    resources = [
      aws_s3_bucket.this.arn,
      "${aws_s3_bucket.this.arn}/*",
    ]
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }

  statement {
    sid    = "DenyUnencryptedObjectUploads"
    effect = "Deny"
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.this.arn}/*"]
    condition {
      test     = "StringNotEquals"
      variable = "s3:x-amz-server-side-encryption"
      values   = ["aws:kms"]
    }
  }

  statement {
    sid    = "DenyIncorrectKmsKey"
    effect = "Deny"
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.this.arn}/*"]
    condition {
      test     = "StringNotEqualsIfExists"
      variable = "s3:x-amz-server-side-encryption-aws-kms-key-id"
      values   = [aws_kms_key.this.arn]
    }
  }
}
