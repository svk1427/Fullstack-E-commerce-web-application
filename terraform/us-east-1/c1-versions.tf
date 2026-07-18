# Terraform Settings Block
terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.31"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.9"
    }
    http = {
      source  = "hashicorp/http"
      version = "~> 3.3"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.20"
    }
  }
  # Adding Backend as S3 for Remote State Storage
  # Update these values in GitHub Secrets or use -backend-config flags
  backend "s3" {
    bucket         = "your-terraform-state-bucket"  # Will be overridden by workflow
    key            = "eks-cluster/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-state-lock"         # Will be overridden by workflow
    encrypt        = true
  }
}

# Terraform AWS Provider Block
provider "aws" {
  region = var.aws_region
}

# Terraform HTTP Provider Block
provider "http" {
  # Configuration options
}
