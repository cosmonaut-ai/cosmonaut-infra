terraform {
  backend "s3" {
    bucket = "cosmonaut-terraform-state"
    key    = "dev/terraform.tfstate"
    region = "us-east-1"
  }
}

