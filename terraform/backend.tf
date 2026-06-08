terraform {
  backend "s3" {
    bucket         = "" # Set via -backend-config in CI/CD
    key            = "" # Set via -backend-config in CI/CD
    region         = "" # Set via -backend-config in CI/CD
    dynamodb_table = "" # Set via -backend-config in CI/CD
    encrypt        = true
  }
}
