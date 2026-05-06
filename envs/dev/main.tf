terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }
}

data "aws_caller_identity" "current" {}

locals {
  cors_allowed_origins = ["https://dev.cosmonaut-ai.com", "http://localhost:5173"]

  # SES is a once-per-account/domain resource, owned by the prod environment.
  # Dev references the same identity by ARN without managing the underlying resources.
  ses_domain_identity_arn = "arn:aws:ses:us-east-2:${data.aws_caller_identity.current.account_id}:identity/cosmonaut-ai.com"
}

provider "aws" {
  region = "us-east-2"
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

module "secrets" {
  source = "../../modules/secrets"
  env    = "dev"
}

module "persistence" {
  source = "../../modules/persistence"
  env    = "dev"
}

module "identity" {
  source                    = "../../modules/identity"
  env                       = "dev"
  google_client_id          = var.google_client_id
  callback_urls             = ["https://dev.cosmonaut-ai.com/callback", "cosmonaut.dev://callback"]
  logout_urls               = ["https://dev.cosmonaut-ai.com", "cosmonaut.dev://"]
  ses_domain_identity_arn   = local.ses_domain_identity_arn
  ses_email_domain          = "cosmonaut-ai.com"
  static_content_cdn_domain = "images.dev.cosmonaut-ai.com"
}

module "compute" {
  source              = "../../modules/compute"
  env                 = "dev"
  dynamodb_table_arn  = module.persistence.table_arn
  dynamodb_table_name = module.persistence.table_name
  ssm_parameter_arns = [
    module.secrets.pinecone_key_arn,
    module.secrets.cloudfront_private_key_arn,
    module.secrets.google_client_secret_arn,
    module.secrets.stripe_api_key_arn,
    module.secrets.stripe_webhook_secret_arn,
    module.secrets.elevenlabs_key_arn,
    module.secrets.buttondown_key_arn,
    module.secrets.admin_api_key_arn
  ]
  api_lambda_image_uri          = var.lambda_uri
  slow_worker_lambda_image_uri  = var.lambda_uri
  fast_worker_lambda_image_uri  = var.lambda_uri
  pinecone_index_name           = var.pinecone_index_name
  cognito_user_pool_id          = module.identity.cognito_user_pool_id
  cognito_user_pool_client_id   = module.identity.cognito_user_pool_client_id
  cognito_user_pool_arn         = module.identity.cognito_user_pool_arn
  cors_allowed_origins          = local.cors_allowed_origins
  mock_auth                     = false
  dev_allowed_emails            = var.dev_allowed_emails
  cloudfront_key_pair_id        = module.frontend.cloudfront_key_pair_id
  gcp_project_id                = "cosmonaut-481723"
  gcp_location                  = "global"
  pinecone_key_name             = module.secrets.pinecone_key_name
  google_client_secret_name     = module.secrets.google_client_secret_name
  cloudfront_private_key_name   = module.secrets.cloudfront_private_key_name
  buttondown_key_name           = module.secrets.buttondown_key_name
  admin_api_key_name            = module.secrets.admin_api_key_name
  domain_name                   = "api.dev.cosmonaut-ai.com"
  frontend_domain_name          = "dev.cosmonaut-ai.com"
  static_content_s3_bucket_arn  = module.static_content.s3_bucket_arn
  static_content_s3_bucket_name = module.static_content.s3_bucket_name
  static_content_cdn_domain     = "images.dev.cosmonaut-ai.com"
  stripe_api_key_name           = module.secrets.stripe_api_key_name
  stripe_webhook_secret_name    = module.secrets.stripe_webhook_secret_name
  elevenlabs_key_name           = module.secrets.elevenlabs_key_name
  stripe_portal_config_id       = "bpc_1SyK6nPGDPZNVxWVVSDCz2gj"
  stripe_price_explorer         = "price_1SyFksPGDPZNVxWVPgXVOvHa"
  stripe_price_cosmonaut        = "price_1SyFlrPGDPZNVxWVBod0IuBJ"
  ses_domain_identity_arn       = local.ses_domain_identity_arn
  ses_email_domain              = "cosmonaut-ai.com"
  posthog_project_token         = var.posthog_project_token
}

module "frontend" {
  source               = "../../modules/frontend"
  env                  = "dev"
  domain_name          = "dev.cosmonaut-ai.com"
  api_function_url     = module.compute.api_function_url
  cors_allowed_origins = local.cors_allowed_origins
  existing_waf_arn     = "arn:aws:wafv2:us-east-1:467508858251:global/webacl/cosmonaut-api-waf/9c542e15-ff8a-4c7b-90fa-1f202d52e139"
}

module "static_content" {
  source               = "../../modules/static_content"
  env                  = "dev"
  domain_name          = "images.dev.cosmonaut-ai.com"
  acm_certificate_arn  = module.frontend.acm_certificate_arn
  cors_allowed_origins = local.cors_allowed_origins
}

moved {
  from = module.images
  to   = module.static_content
}

module "dns" {
  source                                = "../../modules/dns"
  domain_name                           = "cosmonaut-ai.com"
  record_name                           = "dev"
  cloudfront_domain_name                = module.frontend.cloudfront_domain_name
  acm_validation_records                = module.frontend.acm_validation_records
  api_cloudfront_domain_name            = module.frontend.api_cloudfront_domain_name
  api_gateway_domain_name               = module.compute.api_gateway_domain_name
  api_acm_validation_records            = module.compute.api_acm_validation_records
  api_record_name                       = "api.dev"
  streaming_record_name                 = "streaming.dev"
  static_content_record_name            = "images.dev"
  static_content_cloudfront_domain_name = module.static_content.cloudfront_domain_name
}

module "cicd" {
  source       = "../../modules/cicd"
  github_repos = ["cosmonaut-ai/cosmonaut-api", "cosmonaut-ai/cosmonaut-web"]
  env          = "dev"
}

variable "google_client_id" {
  type        = string
  description = "Google OAuth Client ID"
}

variable "cloudflare_api_token" {
  type        = string
  description = "Cloudflare API Token with DNS edit permissions"
  sensitive   = true
}

variable "lambda_uri" {
  type        = string
  description = "Image URI of the Lambda functions"
}

variable "pinecone_index_name" {
  type        = string
  description = "Name of the Pinecone index"
}

variable "dev_allowed_emails" {
  type        = list(string)
  description = "Email allowlist for dev environment access control"
  default     = []
}

variable "posthog_project_token" {
  type        = string
  description = "PostHog project token (write-only, not sensitive)"
  default     = ""
}
