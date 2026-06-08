variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "purely"
}

variable "environment" {
  description = "Environment (dev, staging, production)"
  type        = string
  default     = "production"
  validation {
    condition     = contains(["dev", "staging", "production"], var.environment)
    error_message = "Environment must be dev, staging, or production."
  }
}

variable "aws_account_id" {
  description = "AWS Account ID (12-digit number)"
  type        = string
  default     = "846898691042"
}

variable "tf_state_bucket" {
  description = "S3 bucket name for Terraform state"
  type        = string
  default     = "purely-terraform-state"
  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]*[a-z0-9]$", var.tf_state_bucket))
    error_message = "S3 bucket name must follow AWS naming conventions."
  }
}

variable "tf_lock_table" {
  description = "DynamoDB table name for Terraform state locking"
  type        = string
  default     = "purely-terraform-locks"
  validation {
    condition     = can(regex("^[a-zA-Z0-9_.-]+$", var.tf_lock_table))
    error_message = "DynamoDB table name must contain only alphanumeric characters, hyphens, underscores, and periods."
  }
}

variable "tf_state_key" {
  description = "S3 key for Terraform state file"
  type        = string
  default     = "terraform.tfstate"
}

variable "github_actions_role_name" {
  description = "IAM role name for GitHub Actions"
  type        = string
  default     = "github-actions-terraform-role"
}

variable "common_tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default = {
    Project     = "purely"
    Environment = "production"
    ManagedBy   = "terraform"
  }
}
