variable "env" {
  description = "The environment name (e.g., dev, prod)"
  type        = string
}

variable "dynamodb_table_arn" {
  description = "ARN of the DynamoDB table"
  type        = string
}

variable "dynamodb_table_name" {
  description = "Name of the DynamoDB table"
  type        = string
}

variable "ssm_parameter_arns" {
  description = "List of SSM parameter ARNs the Lambda needs access to"
  type        = list(string)
}

variable "api_lambda_image_uri" {
  description = "Image URI of the API Lambda function"
  type        = string
}

variable "slow_worker_lambda_image_uri" {
  description = "Image URI of the slow worker Lambda function"
  type        = string
}

variable "fast_worker_lambda_image_uri" {
  description = "Image URI of the fast worker Lambda function"
  type        = string
}

variable "pinecone_index_name" {
  description = "Name of the Pinecone index"
  type        = string
}

variable "cognito_user_pool_id" {
  description = "ID of the Cognito user pool"
  type        = string
}

variable "cognito_user_pool_client_id" {
  description = "ID of the Cognito user pool client"
  type        = string
}

variable "cognito_user_pool_arn" {
  description = "ARN of the Cognito user pool"
  type        = string
}

variable "stripe_api_key_name" {
  description = "Stripe API key name"
  type        = string
}

variable "stripe_webhook_secret_name" {
  description = "Stripe webhook secret name"
  type        = string
}

variable "stripe_portal_config_id" {
  description = "Stripe portal configuration ID"
  type        = string
}

variable "stripe_price_explorer" {
  description = "Stripe price ID for the Explorer tier"
  type        = string
}

variable "stripe_price_cosmonaut" {
  description = "Stripe price ID for the Cosmonaut tier"
  type        = string
}

variable "cors_allowed_origins" {
  description = "List of allowed origins for CORS"
  type        = list(string)
}

variable "mock_auth" {
  description = "Whether to mock authentication"
  type        = bool
  default     = false
}

variable "cloudfront_key_pair_id" {
  description = "ID of the CloudFront key pair"
  type        = string
}

variable "pinecone_key_name" {
  description = "Name of the Pinecone key"
  type        = string
}

variable "gcp_project_id" {
  description = "GCP project ID for Vertex AI"
  type        = string
}

variable "gcp_location" {
  description = "GCP region for Vertex AI"
  type        = string
  default     = "us-central1"
}

variable "google_client_secret_name" {
  description = "Name of the Google client secret"
  type        = string
}

variable "cloudfront_private_key_name" {
  description = "Name of the CloudFront private key"
  type        = string
}

variable "buttondown_key_name" {
  description = "Name of the Buttondown API key"
  type        = string
}

variable "domain_name" {
  description = "The domain name for the API (e.g., api.cosmonaut-ai.com)"
  type        = string
}

variable "frontend_domain_name" {
  description = "The domain name for the frontend (e.g., cosmonaut-ai.com)"
  type        = string
}
variable "static_content_s3_bucket_arn" {
  description = "ARN of the static content S3 bucket"
  type        = string
}

variable "static_content_s3_bucket_name" {
  description = "Name of the static content S3 bucket"
  type        = string
}

variable "static_content_cdn_domain" {
  description = "Custom domain for the static content CDN (e.g., images.dev.cosmonaut-ai.com)"
  type        = string
}

variable "lambda_architecture" {
  description = "Architecture for Lambda functions (x86_64 or arm64)"
  type        = string
  default     = "arm64"
}

variable "api_memory_size" {
  description = "Memory size for the API Lambda function"
  type        = number
  default     = 1769
}

variable "worker_fast_memory_size" {
  description = "Memory size for the fast worker Lambda function"
  type        = number
  default     = 1769
}

variable "webhook_route_prefix" {
  description = "Route prefix for unauthenticated webhook endpoints (e.g., /webhook/stripe). Requests to this path bypass JWT auth so external services like Stripe can reach the Lambda."
  type        = string
  default     = "/webhooks"
}

variable "elevenlabs_key_name" {
  description = "SSM parameter name for the ElevenLabs API key"
  type        = string
}

variable "log_retention_days" {
  description = "Number of days to retain CloudWatch logs for Lambda functions"
  type        = number
  default     = 30
}

variable "ses_domain_identity_arn" {
  description = "ARN of the SES domain identity for sending emails"
  type        = string
  default     = ""
}

variable "ses_email_domain" {
  description = "Root domain for SES from-email address (e.g. cosmonaut-ai.com). Used when SES is enabled."
  type        = string
  default     = ""
}

variable "alarm_sns_topic_arn" {
  description = "ARN of SNS topic for CloudWatch alarm notifications. If empty, alarms are created but do not send notifications."
  type        = string
  default     = ""
}
