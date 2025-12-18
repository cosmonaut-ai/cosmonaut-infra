terraform {
  backend "s3" {
    bucket = "cosmonaut-terraform-state"
    key    = "prod/terraform.tfstate"
    region = "us-east-1"
  }
}

