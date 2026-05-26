# Get current AWS account ID to construct OIDC provider ARN
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  github_oidc_provider_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/token.actions.githubusercontent.com"
  github_oidc_subjects = flatten([
    for repo in var.github_repos : [
      for ref in var.github_allowed_refs : "repo:${repo}:ref:${ref}"
    ]
  ])

  frontend_bucket_arns        = [for env in var.deploy_envs : "arn:aws:s3:::cosmonaut-${env}-frontend"]
  frontend_bucket_object_arns = [for arn in local.frontend_bucket_arns : "${arn}/*"]
  ecr_repository_arns = [
    for env in var.deploy_envs :
    "arn:aws:ecr:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:repository/cosmonaut-${env}-repo"
  ]
  deploy_lambda_function_arns = flatten([
    for env in var.deploy_envs : [
      "arn:aws:lambda:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:function:cosmonaut-${env}-api",
      "arn:aws:lambda:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:function:cosmonaut-${env}-api-streaming",
      "arn:aws:lambda:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:function:cosmonaut-${env}-worker-fast",
      "arn:aws:lambda:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:function:cosmonaut-${env}-worker-slow",
    ]
  ])
}

# Reference existing GitHub Actions OIDC provider (already exists in AWS)
# ARN format: arn:aws:iam::ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com
# Create the OIDC Provider in AWS to trust GitHub Actions
resource "aws_iam_openid_connect_provider" "github" {
  count = var.env == "dev" ? 1 : 0

  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]

  # GitHub's OIDC Thumbprint (Required by AWS)
  # This matches the certificate for token.actions.githubusercontent.com
  thumbprint_list = ["1c58a3a8518e8759bf075b76b750d4f2df264fcd", "6938fd4d98bab03faadb97b34396831e3780aea1"]
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
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
            "token.actions.githubusercontent.com:sub" = local.github_oidc_subjects
          }
        }
      }
    ]
  })
}

resource "aws_iam_policy" "github_actions_deploy" {
  name        = "cosmonaut-${var.env}-github-actions-deploy-policy"
  description = "Least-privilege deploy access for Cosmonaut GitHub Actions"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "EcrAuth"
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken"]
        Resource = "*"
      },
      {
        Sid    = "EcrPush"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:BatchGetImage",
          "ecr:CompleteLayerUpload",
          "ecr:DescribeImages",
          "ecr:DescribeRepositories",
          "ecr:InitiateLayerUpload",
          "ecr:PutImage",
          "ecr:UploadLayerPart",
        ]
        Resource = local.ecr_repository_arns
      },
      {
        Sid    = "LambdaLayerDownload"
        Effect = "Allow"
        Action = [
          "lambda:GetLayerVersion",
          "lambda:GetLayerVersionByArn",
        ]
        Resource = "arn:aws:lambda:us-east-2:590474943231:layer:AWS-Parameters-and-Secrets-Lambda-Extension-Arm64:25"
      },
      {
        Sid    = "LambdaDeploy"
        Effect = "Allow"
        Action = [
          "lambda:GetFunction",
          "lambda:GetFunctionConfiguration",
          "lambda:UpdateFunctionCode",
        ]
        Resource = local.deploy_lambda_function_arns
      },
      {
        Sid    = "FrontendBucketList"
        Effect = "Allow"
        Action = [
          "s3:GetBucketLocation",
          "s3:ListBucket",
          "s3:ListBucketMultipartUploads",
        ]
        Resource = local.frontend_bucket_arns
      },
      {
        Sid    = "FrontendObjectDeploy"
        Effect = "Allow"
        Action = [
          "s3:AbortMultipartUpload",
          "s3:DeleteObject",
          "s3:GetObject",
          "s3:ListMultipartUploadParts",
          "s3:PutObject",
        ]
        Resource = local.frontend_bucket_object_arns
      },
      {
        Sid    = "CloudFrontInvalidate"
        Effect = "Allow"
        Action = [
          "cloudfront:CreateInvalidation",
          "cloudfront:GetDistribution",
          "cloudfront:GetInvalidation",
        ]
        Resource = "*"
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "deploy" {
  role       = aws_iam_role.github_actions.name
  policy_arn = aws_iam_policy.github_actions_deploy.arn
}


resource "aws_ecr_repository" "repo" {
  name                 = "cosmonaut-${var.env}-repo"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_lifecycle_policy" "repo_policy" {
  repository = aws_ecr_repository.repo.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 3 images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 3
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
