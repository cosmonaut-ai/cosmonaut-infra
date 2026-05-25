# Infrastructure Structure

`cosmonaut-infra` is organized around environment root modules in `envs/` and reusable Terraform modules in `modules/`.

```text
cosmonaut-infra/
├── envs/
│   ├── dev/
│   │   ├── backend.tf
│   │   ├── main.tf
│   │   └── terraform.tfvars       # ignored locally when private values are present
│   └── prod/
│       ├── backend.tf
│       ├── main.tf
│       └── terraform.tfvars       # ignored locally when private values are present
├── lambdas/
│   ├── custom_message/            # Cognito custom-message trigger source
│   └── pre_sign_up/               # Cognito pre-sign-up trigger source
├── modules/
│   ├── cicd/                      # GitHub Actions OIDC roles
│   ├── compute/                   # API Gateway, Lambda functions, SQS, IAM, alarms
│   ├── dns/                       # Cloudflare DNS records
│   ├── email/                     # SES identities and records
│   ├── frontend/                  # S3 + CloudFront frontend hosting
│   ├── identity/                  # Cognito user pool, app clients, identity providers
│   ├── persistence/               # DynamoDB tables
│   ├── secrets/                   # SSM Parameter Store placeholders
│   └── static_content/            # Static content bucket/CDN resources
├── scripts/
│   └── setup_secrets.sh           # Helper for populating selected SSM secrets
└── docs/
```

## Environment Roots

`envs/dev` and `envs/prod` instantiate the same module set with environment-specific names, domains, URLs, Stripe price IDs, Cognito callback URLs, and deployment role configuration.

Run Terraform from the environment directory:

```bash
cd envs/dev
terraform init
terraform plan
terraform apply
```

## Module Notes

### `modules/secrets`

Creates SSM Parameter Store placeholders for runtime secrets. The placeholder resources use `ignore_changes` so Terraform tracks the parameter names and ARNs without storing updated secret values in source control or state diffs.

Examples include:

- `/<env>/cosmonaut/pinecone_api_key`
- `/<env>/cosmonaut/google_client_secret`
- `/<env>/cosmonaut/cloudfront_private_key`
- `/<env>/cosmonaut/stripe_api_key`
- `/<env>/cosmonaut/stripe_webhook_secret`
- `/<env>/cosmonaut/elevenlabs_api_key`

### `modules/compute`

Defines the API Gateway, Lambda functions, SQS queues, IAM permissions, environment variables, and alarms for the API and workers. Lambda code is deployed from the application repository CI/CD flow.

### `modules/frontend`

Defines S3 and CloudFront resources for the static web frontend. The web repository deploy workflow builds the SvelteKit app and syncs the `build/` output to these resources.

### `modules/identity`

Defines Cognito user pools, app clients, OAuth provider configuration, and trigger Lambda wiring for authentication. Google client secrets are read from SSM Parameter Store.

### `modules/cicd`

Defines OIDC trust and IAM roles used by GitHub Actions. Keep trust policies scoped to the expected organization, repositories, branches, and workflow needs.

## Public Repository Notes

The repository intentionally exposes infrastructure topology, public domains, and public client identifiers. It must not expose Terraform state, raw secret values, private `.tfvars` values, provider caches, or generated deployment packages.
