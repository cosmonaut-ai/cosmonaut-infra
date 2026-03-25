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

locals {
  cors_allowed_origins = ["https://cosmonaut-ai.com"]
}

# SNS topic for CloudWatch alarm notifications
resource "aws_sns_topic" "alarm_notifications" {
  name = "cosmonaut-prod-alarm-notifications"
}

resource "aws_sns_topic_subscription" "alarm_email" {
  topic_arn = aws_sns_topic.alarm_notifications.arn
  protocol  = "email"
  endpoint  = var.alarm_notification_email
}

provider "aws" {
  region = "us-east-2"
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

module "secrets" {
  source = "../../modules/secrets"
  env    = "prod"
}

module "persistence" {
  source = "../../modules/persistence"
  env    = "prod"
}

module "email" {
  source      = "../../modules/email"
  domain_name = "cosmonaut-ai.com"
}

module "identity" {
  source                    = "../../modules/identity"
  env                       = "prod"
  google_client_id          = var.google_client_id
  callback_urls             = ["https://cosmonaut-ai.com/callback"]
  logout_urls               = ["https://cosmonaut-ai.com"]
  ses_domain_identity_arn   = module.email.ses_domain_identity_arn
  ses_email_domain          = "cosmonaut-ai.com"
  static_content_cdn_domain = "images.cosmonaut-ai.com"
}

module "compute" {
  source              = "../../modules/compute"
  env                 = "prod"
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
  api_lambda_image_uri          = var.api_lambda_image_uri
  slow_worker_lambda_image_uri  = var.slow_worker_lambda_image_uri
  fast_worker_lambda_image_uri  = var.fast_worker_lambda_image_uri
  pinecone_index_name           = var.pinecone_index_name
  cognito_user_pool_id          = module.identity.cognito_user_pool_id
  cognito_user_pool_client_id   = module.identity.cognito_user_pool_client_id
  cognito_user_pool_arn         = module.identity.cognito_user_pool_arn
  cors_allowed_origins          = local.cors_allowed_origins
  mock_auth                     = false
  cloudfront_key_pair_id        = module.frontend.cloudfront_key_pair_id
  gcp_project_id                = "cosmonaut-481723"
  gcp_location                  = "global"
  pinecone_key_name             = module.secrets.pinecone_key_name
  google_client_secret_name     = module.secrets.google_client_secret_name
  cloudfront_private_key_name   = module.secrets.cloudfront_private_key_name
  buttondown_key_name           = module.secrets.buttondown_key_name
  admin_api_key_name            = module.secrets.admin_api_key_name
  domain_name                   = "api.cosmonaut-ai.com"
  frontend_domain_name          = "cosmonaut-ai.com"
  static_content_s3_bucket_arn  = module.static_content.s3_bucket_arn
  static_content_s3_bucket_name = module.static_content.s3_bucket_name
  static_content_cdn_domain     = "images.cosmonaut-ai.com"
  stripe_api_key_name           = module.secrets.stripe_api_key_name
  stripe_webhook_secret_name    = module.secrets.stripe_webhook_secret_name
  elevenlabs_key_name           = module.secrets.elevenlabs_key_name
  stripe_portal_config_id       = "bpc_1SyKcQAk6UN4EuOPQ1DFcu0v"
  alarm_sns_topic_arn           = aws_sns_topic.alarm_notifications.arn
  stripe_price_explorer         = "price_1SyKZzAk6UN4EuOPzJJPIyND"
  stripe_price_cosmonaut        = "price_1SyKZvAk6UN4EuOPGsTySbju"
  ses_domain_identity_arn       = module.email.ses_domain_identity_arn
  ses_email_domain              = "cosmonaut-ai.com"
}

module "frontend" {
  source               = "../../modules/frontend"
  env                  = "prod"
  domain_name          = "cosmonaut-ai.com"
  api_function_url     = module.compute.api_function_url
  cors_allowed_origins = local.cors_allowed_origins
}

module "static_content" {
  source               = "../../modules/static_content"
  env                  = "prod"
  domain_name          = "images.cosmonaut-ai.com"
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
  record_name                           = "@" # @ represents the root domain
  cloudfront_domain_name                = module.frontend.cloudfront_domain_name
  acm_validation_records                = module.frontend.acm_validation_records
  api_cloudfront_domain_name            = module.frontend.api_cloudfront_domain_name
  api_gateway_domain_name               = module.compute.api_gateway_domain_name
  api_acm_validation_records            = module.compute.api_acm_validation_records
  api_record_name                       = "api"
  streaming_record_name                 = "streaming"
  static_content_record_name            = "images"
  static_content_cloudfront_domain_name = module.static_content.cloudfront_domain_name
  ses_enabled                           = true
  ses_domain_verification_token         = module.email.ses_domain_identity_verification_token
  ses_dkim_tokens                       = module.email.ses_dkim_tokens
  ses_mail_from_domain                  = module.email.mail_from_domain
}

module "cicd" {
  source       = "../../modules/cicd"
  github_repos = ["cosmonaut-ai/cosmonaut-api", "cosmonaut-ai/cosmonaut-web"]
  env          = "prod"
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

variable "api_lambda_image_uri" {
  type        = string
  description = "Image URI of the API Lambda function"
}

variable "slow_worker_lambda_image_uri" {
  type        = string
  description = "Image URI of the slow worker Lambda function"
}

variable "fast_worker_lambda_image_uri" {
  type        = string
  description = "Image URI of the fast worker Lambda function"
}

variable "pinecone_index_name" {
  type        = string
  description = "Name of the Pinecone index"
}

variable "alarm_notification_email" {
  type        = string
  description = "Email address to receive CloudWatch alarm notifications"
  default     = "imatson9119@gmail.com"
}
