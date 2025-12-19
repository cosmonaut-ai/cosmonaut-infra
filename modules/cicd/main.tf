# Get current AWS account ID to construct OIDC provider ARN
data "aws_caller_identity" "current" {}

# Reference existing GitHub Actions OIDC provider (already exists in AWS)
# ARN format: arn:aws:iam::ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com
locals {
  github_oidc_provider_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/token.actions.githubusercontent.com"
}

resource "aws_iam_role" "github_actions" {
  name = "cosmonaut-github-actions-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = local.github_oidc_provider_arn
        }
        Condition = {
          StringLike = {
            "token.actions.githubusercontent.com:sub" : "repo:${var.github_repo}:*"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "admin" {
  role       = aws_iam_role.github_actions.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess" # For initial setup, can be narrowed later
}

