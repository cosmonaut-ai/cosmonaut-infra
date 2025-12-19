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
  github_repo = "your-org/cosmonaut-infra" # Update with actual repo
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

