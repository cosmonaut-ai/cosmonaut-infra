resource "aws_ssm_parameter" "pinecone_key" {
  name  = "/${var.env}/cosmonaut/pinecone_api_key"
  type  = "SecureString"
  value = "CHANGE_ME"
  lifecycle {
    ignore_changes = [value]
  }
}

resource "aws_ssm_parameter" "gemini_key" {
  name  = "/${var.env}/cosmonaut/gemini_api_key"
  type  = "SecureString"
  value = "CHANGE_ME"
  lifecycle {
    ignore_changes = [value]
  }
}

resource "aws_ssm_parameter" "google_client_secret" {
  name  = "/${var.env}/cosmonaut/google_client_secret"
  type  = "SecureString"
  value = "CHANGE_ME"
  lifecycle {
    ignore_changes = [value]
  }
}

resource "aws_ssm_parameter" "cloudfront_private_key" {
  name  = "/${var.env}/cosmonaut/cloudfront_private_key"
  type  = "SecureString"
  value = "CHANGE_ME"
  lifecycle {
    ignore_changes = [value]
  }
}

resource "aws_ssm_parameter" "stripe_api_key" {
  name  = "/${var.env}/cosmonaut/stripe_api_key"
  type  = "SecureString"
  value = "CHANGE_ME"
  lifecycle {
    ignore_changes = [value]
  }
}

resource "aws_ssm_parameter" "stripe_webhook_secret" {
  name  = "/${var.env}/cosmonaut/stripe_webhook_secret"
  type  = "SecureString"
  value = "CHANGE_ME"
  lifecycle {
    ignore_changes = [value]
  }
}
