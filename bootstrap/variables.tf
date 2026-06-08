variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "purely"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}

variable "tf_state_bucket" {
  description = "S3 bucket name for Terraform state"
  type        = string
  default     = "purely-terraform-state"
}

variable "tf_lock_table" {
  description = "DynamoDB table name for locks"
  type        = string
  default     = "purely-terraform-locks"
}

variable "github_actions_role_name" {
  description = "IAM role name for GitHub Actions"
  type        = string
  default     = "github-actions-terraform-role"
}

variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default = {
    Project     = "purely"
    Environment = "production"
    ManagedBy   = "terraform"
  }
}
