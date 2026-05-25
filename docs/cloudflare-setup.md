# Cloudflare DNS Integration Guide

Cosmonaut uses Cloudflare DNS with AWS CloudFront, ACM, and S3/API Gateway-backed services.

## What Terraform Manages

- Cloudflare DNS records for dev and production domains.
- ACM certificate validation records.
- Frontend, API, streaming, and static content hostnames.

AWS resources are created in the AWS account; Cloudflare remains the authoritative DNS provider for `cosmonaut-ai.com`.

## Prerequisites

- Domain active in Cloudflare.
- AWS credentials with permission to run the target environment's Terraform.
- Cloudflare API token with least-privilege DNS access for the target zone.

## Create a Cloudflare API Token

Use the Cloudflare dashboard:

1. Open **My Profile -> API Tokens**.
2. Create a token from the **Edit zone DNS** template.
3. Scope it to the `cosmonaut-ai.com` zone.
4. Grant:
   - `Zone:DNS:Edit`
   - `Zone:Zone:Read`
5. Copy the token immediately and store it in a password manager or secrets manager.

Do not use a global API key.

## Local Configuration

Terraform reads the token from `TF_VAR_cloudflare_api_token`.

```bash
export TF_VAR_cloudflare_api_token="..."
```

Or copy the example file and load it through `direnv`:

```bash
cp .env.example .envrc
direnv allow
```

## GitHub Actions Configuration

For CI/CD, store the token as a repository or organization secret named `CLOUDFLARE_API_TOKEN`, then expose it to Terraform as:

```yaml
env:
  TF_VAR_cloudflare_api_token: ${{ secrets.CLOUDFLARE_API_TOKEN }}
```

Keep the token scoped to DNS management for the specific Cloudflare zone.

## Runtime Secrets

Cloudflare DNS setup is separate from runtime API secrets. Runtime secrets are stored in AWS SSM Parameter Store under `/<env>/cosmonaut/...`.

The `modules/secrets` module creates placeholders for values such as:

- `pinecone_api_key`
- `gemini_api_key`
- `google_client_secret`
- `cloudfront_private_key`
- `stripe_api_key`
- `stripe_webhook_secret`
- `elevenlabs_api_key`
- `buttondown_api_key`
- `admin_api_key`

The helper script currently prompts for the core API secrets:

```bash
./scripts/setup_secrets.sh dev
./scripts/setup_secrets.sh prod
```

Populate any remaining placeholders directly in SSM before exercising the dependent feature.

## Apply

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

Check plans before applying. DNS and certificate changes can affect live traffic.

## Certificate Validation

ACM certificates are validated through DNS records managed in Cloudflare. If a certificate remains pending:

- Confirm the validation record exists in Cloudflare.
- Confirm the record is not proxied when ACM expects direct DNS validation.
- Check propagation with `dig`.
- Re-run `terraform plan` to verify Terraform still owns the expected records.

## Troubleshooting

### DNS Record Already Exists

Import the existing record into Terraform or remove the unmanaged duplicate from Cloudflare. Avoid creating parallel records for the same hostname.

### CloudFront Certificate Error

CloudFront requires certificates in `us-east-1`. Verify that frontend/static-content certificates are requested in the correct region.

### Terraform Authentication Error

Confirm:

- `TF_VAR_cloudflare_api_token` is set.
- The token has zone read and DNS edit permission.
- The token is scoped to the correct zone.
- The AWS profile or role has the expected permissions.

## Security Checklist

- Use a scoped Cloudflare token, not a global key.
- Do not commit `.envrc`, `.tfvars` with private values, Terraform state, or plan files containing sensitive values.
- Rotate the Cloudflare token if it is pasted into a public issue, pull request, or log.
- Review DNS changes in `terraform plan` before applying production changes.
