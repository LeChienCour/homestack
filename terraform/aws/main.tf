# =============================================================================
# Terraform — AWS SES
# =============================================================================
# Configura el dominio en SES, genera DKIM, crea IAM user para SMTP.

terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.40"
    }
  }

  backend "s3" {
    bucket       = "homestack-tf-state"
    key          = "aws/terraform.tfstate"
    region       = "us-east-1"
    profile      = "admin"
    use_lockfile = true  # Locking nativo S3 — no requiere DynamoDB (TF >= 1.10)
    encrypt      = true
  }
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
