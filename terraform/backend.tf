terraform {
  backend "s3" {
    bucket         = "purely-terraform-state" # Set via -backend-config in CI/CD
    key            = "demo"                   # Set via -backend-config in CI/CD
    region         = "us-east-1"              # Set via -backend-config in CI/CD
    dynamodb_table = "purely-terraform-locks" # Set via -backend-config in CI/CD
    encrypt        = true
  }
}
