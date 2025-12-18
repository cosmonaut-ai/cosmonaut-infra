terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
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
  source               = "../../modules/identity"
  env                  = "dev"
  google_client_id     = var.google_client_id
  google_client_secret = module.secrets.google_client_secret_arn
  callback_urls        = ["https://dev.cosmonaut-ai.com/callback"]
  logout_urls          = ["https://dev.cosmonaut-ai.com"]
}

module "compute" {
  source             = "../../modules/compute"
  env                = "dev"
  dynamodb_table_arn = module.persistence.table_arn
  ssm_parameter_arns = [
    module.secrets.pinecone_key_arn,
    module.secrets.openai_key_arn
  ]
}

module "frontend" {
  source      = "../../modules/frontend"
  env         = "dev"
  domain_name = "dev.cosmonaut-ai.com"
  zone_id     = var.zone_id
}

module "cicd" {
  source      = "../../modules/cicd"
  github_repo = "your-org/cosmonaut-infra" # Update with actual repo
}

variable "google_client_id" {
  type = string
}

variable "zone_id" {
  type = string
}

