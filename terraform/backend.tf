terraform {
  backend "s3" {
    bucket         = ""  # Set via -backend-config in CI/CD workflows
    key            = ""  # Set via -backend-config in CI/CD workflows
    region         = ""  # Set via -backend-config in CI/CD workflows
    dynamodb_table = ""  # Set via -backend-config in CI/CD workflows
    encrypt        = true
  }
}
