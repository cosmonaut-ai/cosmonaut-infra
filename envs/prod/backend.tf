terraform {
  backend "s3" {
    bucket         = "cosmonaut-ai-terraform-state"
    key            = "prod/terraform.tfstate"
    region         = "us-east-2"
    dynamodb_table = "cosmonaut-terraform-state-lock"
    encrypt        = true
  }
}

