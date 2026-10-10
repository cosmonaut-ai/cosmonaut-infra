# Cosmonaut Infrastructure

Terraform infrastructure for [Cosmonaut AI](https://cosmonaut-ai.com), an AI-powered interactive storytelling platform.

This repository provisions the AWS and Cloudflare resources used by the API, web app, authentication, static content, email, DNS, and deployment roles.

## Repository Role

Cosmonaut is split across several public repositories:

- [`cosmonaut-web`](https://github.com/cosmonaut-ai/cosmonaut-web): SvelteKit frontend.
- [`cosmonaut-api`](https://github.com/cosmonaut-ai/cosmonaut-api): Backend API and workers.
- [`cosmonaut-infra`](https://github.com/cosmonaut-ai/cosmonaut-infra): Terraform infrastructure.
- [`cosmonaut-android`](https://github.com/cosmonaut-ai/cosmonaut-android): Native Android client.

## Stack

- Terraform
- AWS Lambda, API Gateway, SQS, DynamoDB, S3, CloudFront, ACM, SES, Cognito, IAM, SSM Parameter Store
- Cloudflare DNS
- GitHub Actions OIDC roles for deployment from the app repositories

## Structure

```text
envs/
├── dev/                 # Development environment root module
└── prod/                # Production environment root module
modules/
├── cicd/                # GitHub Actions OIDC IAM roles
├── compute/             # API Gateway, Lambda, SQS, IAM, alarms
├── dns/                 # Cloudflare DNS records
├── email/               # SES identities and email auth
├── frontend/            # S3 + CloudFront frontend hosting
├── identity/            # Cognito user pool, app clients, hosted UI
├── persistence/         # DynamoDB tables
├── secrets/             # SSM Parameter placeholders
└── static_content/      # Static content buckets/CDN
lambdas/                 # Cognito trigger Lambda source
scripts/                 # Operational helper scripts
docs/                    # Setup and architecture notes
```

## Local Setup

Prerequisites:

- Terraform
- AWS CLI credentials for the target account
- Cloudflare API token with DNS edit permissions for the target zone

```bash
cp .env.example .envrc
```

Fill in `.envrc`, then load it with `direnv allow` or `source .envrc`.

## Secrets

Terraform creates SSM Parameter Store placeholders for runtime secrets. The placeholders intentionally use `ignore_changes` so raw secret values are not managed in Terraform state.

Use the helper script for the core API secrets:

```bash
./scripts/setup_secrets.sh dev
./scripts/setup_secrets.sh prod
```

Some secrets, such as Stripe webhook secrets and CloudFront private keys, may still need to be populated directly in SSM depending on the environment. Never commit `.tfvars` files with private values, Terraform state, Cloudflare tokens, or generated Lambda packages.

## Planning and Applying

Development:

```bash
cd envs/dev
terraform init
terraform plan
terraform apply
```

Production:

```bash
cd envs/prod
terraform init
terraform plan
terraform apply
```

Review plans carefully before applying. Infrastructure changes can affect live production traffic.

## CI/CD Integration

The `modules/cicd` module creates the GitHub Actions OIDC deploy role used by the API and web workflows. The application repositories expect an `AWS_ROLE_ARN` GitHub Actions secret that points at that role.

This repository runs Terraform through `.github/workflows/terraform.yml`:

- Pull requests to `main` run `terraform plan` for dev and prod and post each plan as a pull request comment.
- Pushes to `main` apply dev, then apply prod after a reviewer approves the `prod` GitHub environment.

The workflow uses two roles from `modules/terraform_ci`, which is managed by the dev environment:

- `cosmonaut-terraform-plan`: read-only, assumable only by pull request jobs in this repository.
- `cosmonaut-terraform-apply`: administrator, assumable only by jobs in the `dev` and `prod` GitHub environments of this repository.

It reads this GitHub configuration:

| Name | Kind | Value |
|---|---|---|
| `TF_PLAN_ROLE_ARN` | Variable | ARN of `cosmonaut-terraform-plan` |
| `TF_APPLY_ROLE_ARN` | Variable | ARN of `cosmonaut-terraform-apply` |
| `TF_VARS_DEV` | Variable | `.tfvars` content for `envs/dev`, without `cloudflare_api_token` |
| `TF_VARS_PROD` | Variable | `.tfvars` content for `envs/prod`, without `cloudflare_api_token` |
| `CLOUDFLARE_API_TOKEN` | Secret | Cloudflare token passed as `TF_VAR_cloudflare_api_token` |

This repository is public, so workflow logs and plan comments are public. Keep secret values in `sensitive` variables or SSM, never in `TF_VARS_*`.

## Documentation

Start with [`docs/README.md`](docs/README.md). The most useful references are:

- [`docs/structure.md`](docs/structure.md): module map and design notes.
- [`docs/cloudflare-setup.md`](docs/cloudflare-setup.md): Cloudflare DNS and token setup.
- [`docs/email-password-auth-setup.md`](docs/email-password-auth-setup.md): Cognito email/password setup notes.
- [`docs/audio-implementation.md`](docs/audio-implementation.md): infrastructure support for narration.

## Security

See [`SECURITY.md`](SECURITY.md) for disclosure and secret-handling guidance.

## Contributing

Issues and pull requests are welcome. For Terraform changes, include the relevant `terraform plan` output summary and avoid committing generated local state or provider caches.

## License

Apache-2.0. See [`LICENSE`](LICENSE).
