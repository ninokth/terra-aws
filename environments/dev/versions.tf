# Development Environment - Terraform Configuration
# Uses bastion NAT for cost-effective development

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.14"
    }
  }

  # For production, configure remote backend:
  # backend "s3" {
  #   bucket         = "your-terraform-state-bucket"
  #   key            = "terraform-aws/dev/terraform.tfstate"
  #   region         = "eu-north-1"
  #   encrypt        = true
  #   dynamodb_table = "terraform-state-lock"
  # }
}
