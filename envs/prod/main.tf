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

module "identity" {
  source           = "../../modules/identity"
  env              = "prod"
  google_client_id = var.google_client_id
  callback_urls    = ["https://cosmonaut-ai.com/callback"]
  logout_urls      = ["https://cosmonaut-ai.com"]
}

module "compute" {
  source             = "../../modules/compute"
  env                = "prod"
  dynamodb_table_arn = module.persistence.table_arn
  ssm_parameter_arns = [
    module.secrets.pinecone_key_arn,
    module.secrets.gemini_key_arn,
    module.secrets.cloudfront_private_key_arn,
    module.secrets.google_client_secret_arn
  ]
  api_lambda_image_uri         = var.api_lambda_image_uri
  slow_worker_lambda_image_uri = var.slow_worker_lambda_image_uri
  fast_worker_lambda_image_uri = var.fast_worker_lambda_image_uri
  pinecone_index_name          = var.pinecone_index_name
  cognito_user_pool_id         = module.identity.cognito_user_pool_id
  cognito_user_pool_client_id  = module.identity.cognito_user_pool_client_id
  cors_allowed_origins         = local.cors_allowed_origins
  mock_auth                    = false
  cloudfront_key_pair_id       = module.frontend.cloudfront_key_pair_id
  pinecone_key_name            = module.secrets.pinecone_key_name
  gemini_key_name              = module.secrets.gemini_key_name
  google_client_secret_name    = module.secrets.google_client_secret_name
  cloudfront_private_key_name  = module.secrets.cloudfront_private_key_name
  domain_name                  = "api.cosmonaut-ai.com"
}

module "frontend" {
  source           = "../../modules/frontend"
  env              = "prod"
  domain_name      = "cosmonaut-ai.com"
  api_function_url = module.compute.api_function_url
}

module "dns" {
  source                     = "../../modules/dns"
  domain_name                = "cosmonaut-ai.com"
  record_name                = "@" # @ represents the root domain
  cloudfront_domain_name     = module.frontend.cloudfront_domain_name
  acm_validation_records     = module.frontend.acm_validation_records
  api_cloudfront_domain_name = module.frontend.api_cloudfront_domain_name
  api_gateway_domain_name    = module.compute.api_gateway_domain_name
  api_acm_validation_records = module.compute.api_acm_validation_records
  api_record_name            = "api"
  streaming_record_name      = "streaming"
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
