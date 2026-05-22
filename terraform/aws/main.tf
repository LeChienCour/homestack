# =============================================================================
# Terraform — AWS SES
# =============================================================================
# Configura el dominio en SES, genera DKIM, crea IAM user para SMTP.

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.40"
    }
  }

  # backend "s3" {
  #   # Opcional: si quieres state remoto en S3
  #   bucket = "homestack-tf-state"
  #   key    = "aws/terraform.tfstate"
  #   region = "us-east-1"
  # }
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
