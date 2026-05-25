# Security Policy

Please do not report security issues in public GitHub issues.

Report vulnerabilities or accidental secret exposure to `support@cosmonaut-ai.com` with the affected repository, file path, and reproduction details.

## Secret Handling

- Do not commit Terraform state, `.tfvars` files with private values, AWS credentials, Cloudflare API tokens, private keys, or generated Lambda packages.
- Keep runtime secrets in AWS SSM Parameter Store or GitHub Actions secrets.
- Review IAM trust policies and GitHub Actions OIDC permissions before making this repository public.
