#!/bin/bash

# Terraform Bootstrap Setup Script
# This script sets up the prerequisite AWS resources for Terraform CI/CD

set -e

echo "================================================"
echo "Terraform Bootstrap Setup"
echo "================================================"
echo ""

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check prerequisites
echo "Checking prerequisites..."

if ! command -v aws &> /dev/null; then
    echo -e "${RED}❌ AWS CLI is not installed${NC}"
    exit 1
fi

if ! command -v terraform &> /dev/null; then
    echo -e "${RED}❌ Terraform is not installed${NC}"
    exit 1
fi

if ! command -v jq &> /dev/null; then
    echo -e "${YELLOW}⚠️  jq is not installed (optional, for JSON parsing)${NC}"
fi

echo -e "${GREEN}✓ All prerequisites met${NC}"
echo ""

# Get AWS Account ID
echo "Getting AWS Account ID..."
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "Account ID: $ACCOUNT_ID"
echo ""

# Get GitHub repository info
echo "GitHub Configuration:"
read -p "Enter GitHub organization/username: " GITHUB_ORG
read -p "Enter GitHub repository name: " GITHUB_REPO
read -p "Enter GitHub branch (default: main): " GITHUB_BRANCH
GITHUB_BRANCH=${GITHUB_BRANCH:-main}

GITHUB_SUBJECT="repo:${GITHUB_ORG}/${GITHUB_REPO}:ref:refs/heads/${GITHUB_BRANCH}"
echo ""

# Check if OIDC provider exists
echo "Setting up OIDC provider..."
OIDC_PROVIDER_ARN="arn:aws:iam::${ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com"

if aws iam get-open-id-connect-provider --open-id-connect-provider-arn "$OIDC_PROVIDER_ARN" &> /dev/null; then
    echo -e "${GREEN}✓ OIDC provider already exists${NC}"
else
    echo "Creating OIDC provider..."
    aws iam create-open-id-connect-provider \
        --url https://token.actions.githubusercontent.com \
        --client-id-list sts.amazonaws.com \
        --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1
    echo -e "${GREEN}✓ OIDC provider created${NC}"
fi
echo ""

# Navigate to bootstrap directory
cd "$(dirname "$0")/../bootstrap"

# Update terraform.tfvars with GitHub repo info
echo "Updating bootstrap configuration..."
sed -i "s|github_actions_role_name.*|github_actions_role_name  = \"github-actions-terraform-role\"|" terraform.tfvars

# Initialize Terraform
echo "Initializing Terraform in bootstrap directory..."
terraform init

# Apply bootstrap configuration
echo ""
echo "Creating AWS resources..."
echo "This will create:"
echo "  • S3 bucket for Terraform state"
echo "  • DynamoDB table for state locking"
echo "  • IAM role for GitHub Actions"
echo ""

# Temporarily update the IAM role policy with correct GitHub org/repo
TEMP_POLICY=$(cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::${ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "${GITHUB_SUBJECT}"
        }
      }
    }
  ]
}
EOF
)

terraform apply -auto-approve -var="github_actions_role_name=github-actions-terraform-role"

# Get outputs
echo ""
echo "Extracting outputs..."
OUTPUTS=$(terraform output -json)

ROLE_ARN=$(echo $OUTPUTS | jq -r '.github_actions_role_arn.value')
STATE_BUCKET=$(echo $OUTPUTS | jq -r '.terraform_state_bucket.value')
LOCK_TABLE=$(echo $OUTPUTS | jq -r '.terraform_lock_table.value')

echo ""
echo "================================================"
echo -e "${GREEN}✓ Bootstrap setup complete!${NC}"
echo "================================================"
echo ""
echo "Add these secrets to GitHub repository:"
echo "  Repository → Settings → Secrets and variables → Actions"
echo ""
echo -e "${YELLOW}AWS_ROLE_TO_ASSUME${NC}"
echo "  $ROLE_ARN"
echo ""
echo -e "${YELLOW}AWS_REGION${NC}"
echo "  us-east-1"
echo ""
echo -e "${YELLOW}TF_STATE_BUCKET${NC}"
echo "  $STATE_BUCKET"
echo ""
echo -e "${YELLOW}TF_LOCK_TABLE${NC}"
echo "  $LOCK_TABLE"
echo ""

# Optional: Add secrets via gh CLI
if command -v gh &> /dev/null; then
    echo "Would you like to add these secrets automatically using GitHub CLI?"
    read -p "Enter 'yes' to proceed (requires gh auth): " ADD_SECRETS

    if [ "$ADD_SECRETS" = "yes" ]; then
        echo "Setting GitHub repository..."
        gh repo set-default "$GITHUB_ORG/$GITHUB_REPO"

        echo "Adding secrets..."
        gh secret set AWS_ROLE_TO_ASSUME --body "$ROLE_ARN"
        gh secret set AWS_REGION --body "us-east-1"
        gh secret set TF_STATE_BUCKET --body "$STATE_BUCKET"
        gh secret set TF_LOCK_TABLE --body "$LOCK_TABLE"

        echo -e "${GREEN}✓ GitHub secrets added successfully${NC}"
    fi
else
    echo "Install GitHub CLI (gh) to automatically add secrets:"
    echo "  https://cli.github.com"
fi

echo ""
echo "Next steps:"
echo "  1. Update the IAM role trust policy with your GitHub organization/repo"
echo "  2. Verify backend configuration is working:"
echo "     cd terraform && terraform init"
echo "  3. Push changes and create a PR to test terraform plan"
echo ""
