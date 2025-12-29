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
  source           = "../../modules/identity"
  env              = "dev"
  google_client_id = var.google_client_id
  callback_urls    = ["https://dev.cosmonaut-ai.com/callback"]
  logout_urls      = ["https://dev.cosmonaut-ai.com"]
}

module "compute" {
  source             = "../../modules/compute"
  env                = "dev"
  dynamodb_table_arn = module.persistence.table_arn
  ssm_parameter_arns = [
    module.secrets.pinecone_key_arn,
    module.secrets.gemini_key_arn
  ]
  api_lambda_image_uri         = var.api_lambda_image_uri
  slow_worker_lambda_image_uri = var.slow_worker_lambda_image_uri
  fast_worker_lambda_image_uri = var.fast_worker_lambda_image_uri
  pinecone_index_name          = var.pinecone_index_name
  cognito_user_pool_id         = module.identity.cognito_user_pool_id
  cognito_user_pool_client_id  = module.identity.cognito_user_pool_client_id
  cors_allowed_origins         = ["https://dev.cosmonaut-ai.com", "http://localhost:5173"]
  mock_auth                    = false
}

module "frontend" {
  source      = "../../modules/frontend"
  env         = "dev"
  domain_name = "dev.cosmonaut-ai.com"
}

module "dns" {
  source                 = "../../modules/dns"
  domain_name            = "cosmonaut-ai.com"
  record_name            = "dev"
  cloudfront_domain_name = module.frontend.cloudfront_domain_name
  acm_validation_records = module.frontend.acm_validation_records
}

module "cicd" {
  source      = "../../modules/cicd"
  github_repo = "cosmonaut-ai/cosmonaut-api"
  env         = "dev"
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
