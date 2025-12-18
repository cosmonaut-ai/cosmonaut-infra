### The Folder Structure (Cosmonaut AI)

```text
cosmonaut-infra/
├── .github/
│   └── workflows/
│       ├── plan.yml                # PRs: Terraform Plan
│       └── apply.yml               # Merge: Terraform Apply
├── modules/
│   ├── identity/                   # Cognito (Google Auth)
│   │   ├── main.tf
│   │   ├── outputs.tf
│   │   └── variables.tf
│   ├── persistence/                # DynamoDB (Game State)
│   │   ├── main.tf                 # Single Table Definition
│   │   └── outputs.tf
│   ├── secrets/                    # SSM Parameter Store (API Keys)
│   │   ├── main.tf                 # 'aws_ssm_parameter' resources
│   │   └── variables.tf
│   ├── compute/                    # API Gateway + Lambdas
│   │   ├── main.tf                 # HTTP API v2
│   │   ├── iam.tf                  # Permissions (Lambda -> Dynamo/SSM)
│   │   └── variables.tf
│   ├── frontend/                   # S3 + CloudFront + Route53
│   │   ├── main.tf
│   │   ├── acm.tf                  # SSL Certificate
│   │   └── policies.json           # OAC Policy (Block public S3 access)
│   └── cicd/                       # OIDC for GitHub Actions
│       └── main.tf
├── envs/
│   ├── dev/
│   │   ├── main.tf                 # Instantiates modules
│   │   ├── backend.tf              # S3 State backend
│   │   └── terraform.tfvars        # domain = "dev.cosmonaut-ai.com"
│   └── prod/
│       ├── main.tf
│       ├── backend.tf
│       └── terraform.tfvars        # domain = "cosmonaut-ai.com"
├── scripts/
│   └── setup_secrets.sh            # Helper to push keys to SSM manually
├── .gitignore
└── README.md

```

---

### Module Details

#### 1. `modules/secrets` (The Free "Vault")

Instead of creating secrets _inside_ Terraform (which puts the raw value in your state file—a security risk), this module should define **placeholders** or data sources, and you use the CLI to populate them.

- **Resource:** `aws_ssm_parameter`
- **Type:** `SecureString`
- **Key ID:** `alias/aws/ssm` (The default free key).
- **Logic:**

```hcl
resource "aws_ssm_parameter" "pinecone_key" {
  name  = "/${var.env}/cosmonaut/pinecone_api_key"
  type  = "SecureString"
  value = "CHANGE_ME_IN_CONSOLE" # Terraform creates it, you update it manually
  lifecycle {
    ignore_changes = [value] # Terraform won't overwrite your manual update
  }
}

```

#### 2. `modules/compute` (Accessing the Secrets)

Your Lambda needs permission to decrypt these keys at runtime.

- **IAM Policy:**

```hcl
statement {
  actions   = ["ssm:GetParameter", "ssm:GetParameters"]
  resources = ["arn:aws:ssm:us-east-1:*:parameter/${var.env}/cosmonaut/*"]
}

```

- **Python Logic:** Your Lambda code calls `boto3.client('ssm').get_parameter(...)` during initialization.

#### 3. `modules/frontend` (Best Practice for SPAs)

- **Resource:** `aws_cloudfront_distribution`
- **Key Config:** `custom_error_response`
- **Error Code:** `403` and `404`
- **Response Page:** `/index.html`
- **Response Code:** `200`
- _Why:_ This enables "Client Side Routing." If a user refreshes the page at `cosmonaut-ai.com/story/123`, CloudFront won't find that file. It must serve `index.html` so SvelteKit can handle the URL.

#### 4. `modules/identity` (Google Sign-In)

- **Resource:** `aws_cognito_user_pool`
- **Resource:** `aws_cognito_identity_provider`
- **Config:** You will need to input your **Google Client ID** and **Client Secret** here.
- _Tip:_ Store the Google Client Secret in SSM Parameter Store too, and reference it here!
