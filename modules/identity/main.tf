# Fetch Google Client Secret from SSM Parameter Store
data "aws_ssm_parameter" "google_client_secret" {
  name            = "/${var.env}/cosmonaut/google_client_secret"
  with_decryption = true
}

resource "aws_cognito_user_pool" "main" {
  name = "cosmonaut-${var.env}-user-pool"

  auto_verified_attributes = ["email"]

  password_policy {
    minimum_length    = 8
    require_lowercase = true
    require_numbers   = true
    require_symbols   = true
    require_uppercase = true
  }
}

resource "aws_cognito_user_pool_client" "main" {
  name                                 = "cosmonaut-${var.env}-client"
  user_pool_id                         = aws_cognito_user_pool.main.id
  callback_urls                        = var.callback_urls
  logout_urls                          = var.logout_urls
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_flows                  = ["code", "implicit"]
  allowed_oauth_scopes                 = ["email", "openid", "profile"]
  supported_identity_providers         = ["Google"]

  depends_on = [aws_cognito_identity_provider.google]
}

resource "aws_cognito_user_pool_domain" "main" {
  domain       = "cosmonaut-${var.env}"
  user_pool_id = aws_cognito_user_pool.main.id
}

resource "aws_cognito_identity_provider" "google" {
  user_pool_id  = aws_cognito_user_pool.main.id
  provider_name = "Google"
  provider_type = "Google"

  provider_details = {
    authorize_scopes              = "email openid profile"
    client_id                     = var.google_client_id
    client_secret                 = data.aws_ssm_parameter.google_client_secret.value
    attributes_url_add_attributes = "false"
    authorize_url                 = "https://accounts.google.com/o/oauth2/v2/auth"
    token_url                     = "https://www.googleapis.com/oauth2/v4/token"
    attributes_url                = "https://openidconnect.googleapis.com/v1/userinfo"
  }

  attribute_mapping = {
    email    = "email"
    username = "sub"
  }

  lifecycle {
    ignore_changes = [provider_details]
  }
}

