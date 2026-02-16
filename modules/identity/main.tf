# Fetch Google Client Secret from SSM Parameter Store
data "aws_ssm_parameter" "google_client_secret" {
  name            = "/${var.env}/cosmonaut/google_client_secret"
  with_decryption = true
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

resource "aws_cognito_user_pool" "main" {
  name = "cosmonaut-${var.env}-user-pool"

  username_attributes      = ["email"]
  auto_verified_attributes = ["email"]

  username_configuration {
    case_sensitive = false
  }

  password_policy {
    minimum_length    = 8
    require_lowercase = true
    require_numbers   = true
    require_symbols   = true
    require_uppercase = true
  }

  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }

  verification_message_template {
    default_email_option = "CONFIRM_WITH_CODE"
    email_subject        = "Your Cosmonaut verification code"
    email_message        = "Your verification code is {####}"
  }

  # SES email configuration for branded sending
  dynamic "email_configuration" {
    for_each = var.ses_domain_identity_arn != "" ? [1] : []
    content {
      email_sending_account = "DEVELOPER"
      from_email_address    = "Cosmonaut <noreply@cosmonaut-ai.com>"
      source_arn            = var.ses_domain_identity_arn
    }
  }

  # Lambda triggers for branded emails and account linking
  lambda_config {
    custom_message = aws_lambda_function.custom_message.arn
    pre_sign_up    = aws_lambda_function.pre_sign_up.arn
  }

  schema {
    name                = "email"
    attribute_data_type = "String"
    required            = true
    mutable             = true

    string_attribute_constraints {
      min_length = 0
      max_length = 2048
    }
  }

  schema {
    name                = "tier"
    attribute_data_type = "String"
    mutable             = true

    string_attribute_constraints {
      min_length = 0
      max_length = 256
    }
  }

  schema {
    name                = "stripe_customer_id"
    attribute_data_type = "String"
    mutable             = true

    string_attribute_constraints {
      min_length = 0
      max_length = 256
    }
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
  supported_identity_providers         = ["COGNITO", "Google"]

  explicit_auth_flows = [
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_USER_SRP_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
  ]

  read_attributes = [
    "custom:tier",
    "custom:stripe_customer_id",
    "email",
    "email_verified",
    "family_name",
    "given_name",
    "name",
    "picture",
    "preferred_username",
    "profile",
    "updated_at",
    "zoneinfo"
  ]

  write_attributes = [
    "custom:tier",
    "custom:stripe_customer_id",
    "email",
    "family_name",
    "given_name",
    "name",
    "picture",
    "preferred_username",
    "profile",
    "updated_at",
    "zoneinfo"
  ]

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
    email       = "email"
    username    = "sub"
    given_name  = "given_name"
    family_name = "family_name"
    picture     = "picture"
  }

  lifecycle {
    ignore_changes = [provider_details]
  }
}

# ---------------------------------------------------------------------------
# Custom Message Lambda (branded email templates)
# ---------------------------------------------------------------------------

data "archive_file" "custom_message" {
  type        = "zip"
  source_file = "${path.module}/../../lambdas/custom_message/index.py"
  output_path = "${path.module}/../../lambdas/custom_message/package.zip"
}

resource "aws_lambda_function" "custom_message" {
  function_name    = "cosmonaut-${var.env}-custom-message"
  handler          = "index.handler"
  runtime          = "python3.13"
  role             = aws_iam_role.cognito_triggers.arn
  filename         = data.archive_file.custom_message.output_path
  source_code_hash = data.archive_file.custom_message.output_base64sha256
  timeout          = 5
  memory_size      = 128

  environment {
    variables = {
      STATIC_CONTENT_CDN_DOMAIN = var.static_content_cdn_domain
    }
  }
}

resource "aws_lambda_permission" "custom_message" {
  statement_id  = "AllowCognitoInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.custom_message.function_name
  principal     = "cognito-idp.amazonaws.com"
  source_arn    = aws_cognito_user_pool.main.arn
}

# ---------------------------------------------------------------------------
# Pre Sign-Up Lambda (account de-duplication / linking)
# ---------------------------------------------------------------------------

data "archive_file" "pre_sign_up" {
  type        = "zip"
  source_file = "${path.module}/../../lambdas/pre_sign_up/index.py"
  output_path = "${path.module}/../../lambdas/pre_sign_up/package.zip"
}

resource "aws_lambda_function" "pre_sign_up" {
  function_name    = "cosmonaut-${var.env}-pre-sign-up"
  handler          = "index.handler"
  runtime          = "python3.13"
  role             = aws_iam_role.cognito_triggers.arn
  filename         = data.archive_file.pre_sign_up.output_path
  source_code_hash = data.archive_file.pre_sign_up.output_base64sha256
  timeout          = 10
  memory_size      = 128

  # No environment variables needed — the Lambda reads userPoolId
  # directly from the Cognito trigger event payload.
}

resource "aws_lambda_permission" "pre_sign_up" {
  statement_id  = "AllowCognitoInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.pre_sign_up.function_name
  principal     = "cognito-idp.amazonaws.com"
  source_arn    = aws_cognito_user_pool.main.arn
}

# ---------------------------------------------------------------------------
# Shared IAM role for Cognito trigger Lambdas
# ---------------------------------------------------------------------------

resource "aws_iam_role" "cognito_triggers" {
  name = "cosmonaut-${var.env}-cognito-triggers-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "cognito_triggers_basic" {
  role       = aws_iam_role.cognito_triggers.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_policy" "cognito_triggers_extra" {
  name = "cosmonaut-${var.env}-cognito-triggers-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "cognito-idp:ListUsers",
          "cognito-idp:AdminLinkProviderForUser",
          "cognito-idp:AdminCreateUser",
          "cognito-idp:AdminSetUserPassword",
          "cognito-idp:AdminGetUser"
        ]
        Effect   = "Allow"
        Resource = aws_cognito_user_pool.main.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "cognito_triggers_extra_attach" {
  role       = aws_iam_role.cognito_triggers.name
  policy_arn = aws_iam_policy.cognito_triggers_extra.arn
}
