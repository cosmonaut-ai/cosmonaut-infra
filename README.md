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
cd envs/dev
terraform init
terraform plan
terraform apply
```

## Architecture

See `docs/structure.md` and `docs/project-description.md` for detailed architecture and project goals.

