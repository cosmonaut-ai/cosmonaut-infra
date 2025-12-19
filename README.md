# Cosmonaut AI Infrastructure

Infrastructure as Code for the Cosmonaut AI project, using Terraform and AWS.

## Structure

- `modules/`: Reusable Terraform modules.
- `envs/`: Environment-specific configurations (`dev`, `prod`).
- `scripts/`: Utility scripts.
- `.github/workflows/`: CI/CD pipelines.

## Getting Started

### Prerequisites

- AWS CLI configured
- Terraform >= 1.0

### Setup Secrets

Use the helper script to push required API keys to AWS SSM Parameter Store:

```bash
./scripts/setup_secrets.sh dev
```

### Deployment

To deploy the development environment:

```bash
# 1. Bootstrap the state bucket (first time only)
./scripts/bootstrap_state_bucket.sh

# 2. Initialize Terraform
cd envs/dev
terraform init

# 3. Review and apply
terraform plan
terraform apply
```

## CI/CD Setup

This repository uses GitHub Actions with AWS OIDC authentication for Terraform deployments.

### Initial Setup

1. **Create the OIDC Provider in AWS** (one-time setup):
   ```bash
   aws iam create-open-id-connect-provider \
     --url https://token.actions.githubusercontent.com \
     --client-id-list sts.amazonaws.com \
     --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1
   ```

2. **Deploy the Infrastructure** (including the GitHub Actions IAM role):
   ```bash
   cd envs/dev
   terraform init
   terraform apply
   ```

3. **Get the IAM Role ARN**:
   ```bash
   terraform output -raw github_actions_role_arn
   ```

4. **Configure GitHub Secrets**:
   - Go to your GitHub repository → Settings → Secrets and variables → Actions
   - Add the following secrets:
     - `AWS_ROLE_ARN`: The ARN from step 3 (e.g., `arn:aws:iam::123456789012:role/cosmonaut-github-actions-role`)
     - `CLOUDFLARE_API_TOKEN`: Your Cloudflare API token with DNS edit permissions

### Troubleshooting

If you see the error "Credentials could not be loaded, please check your action inputs":
- Ensure `AWS_ROLE_ARN` is set in GitHub repository secrets
- Verify the OIDC provider exists in AWS (see step 1 above)
- Check that the IAM role exists and has the correct trust policy
- Ensure the GitHub repository name matches the `github_repo` variable in your Terraform configuration

## Architecture

See `docs/structure.md` and `docs/project-description.md` for detailed architecture and project goals.

