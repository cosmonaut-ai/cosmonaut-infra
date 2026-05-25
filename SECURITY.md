# Security Policy

Please do not report security issues in public GitHub issues.

Report vulnerabilities or accidental secret exposure to `support@cosmonaut-ai.com`. Include the affected repository, file path, relevant commit or release, reproduction details, and impact if known.

## Scope

This policy covers Terraform modules, environment configuration, Cognito trigger Lambda source, operational scripts, and documentation in this repository.

## Secret Handling

- Do not commit Terraform state, `.tfvars` files with private values, AWS credentials, Cloudflare API tokens, private keys, generated Lambda packages, or provider caches.
- Runtime secrets belong in AWS SSM Parameter Store. CI/CD-only credentials belong in GitHub Actions secrets. Local overrides belong in ignored local files.
- Public identifiers such as domains, Cognito app client IDs, and ARNs may appear in Terraform, but IAM permissions and trust policies should remain tightly scoped.

## Public Contributions

When opening a pull request, scrub plan output, terminal logs, screenshots, and examples for account-specific credentials, secret values, private customer data, and unmanaged infrastructure identifiers that should not be public.
