# =============================================================================
# Bootstrap — S3 bucket para Terraform state
# =============================================================================
# Corre UNA SOLA VEZ antes de los demás módulos.
# State de este módulo queda LOCAL (es el bootstrapper).
#
# Uso:
#   cd terraform/bootstrap
#   terraform init
#   terraform apply
#
# Después de aplicar, el bucket existe y los demás módulos
# pueden usar el backend S3 con use_lockfile = true (TF >= 1.10).

terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.40"
    }
  }
  # Sin backend — state local intencional (bootstrap no se puede auto-referenciar)
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile

  default_tags {
    tags = {
      Project   = "homestack"
      ManagedBy = "terraform"
    }
  }
}

# -----------------------------------------------------------------------------
# S3 bucket para state files
# -----------------------------------------------------------------------------
resource "aws_s3_bucket" "tf_state" {
  bucket = var.state_bucket_name

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
