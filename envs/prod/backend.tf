terraform {
  backend "s3" {
    bucket       = "cosmonaut-ai-terraform-state"
    key          = "prod/terraform.tfstate"
    region       = "us-east-2"
    encrypt      = true
    use_lockfile = true
  }
}
