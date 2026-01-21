# Production Environment - Terraform Configuration
# Uses AWS NAT Gateway for high availability and security

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.14"
    }
  }

  # RECOMMENDED: Configure remote backend for production
  # backend "s3" {
  #   bucket         = "your-terraform-state-bucket"
  #   key            = "terraform-aws/prod/terraform.tfstate"
  #   region         = "eu-north-1"
  #   encrypt        = true
  #   dynamodb_table = "terraform-state-lock"
  # }
}
