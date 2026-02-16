variable "env" {
  description = "The environment name (e.g., dev, prod)"
  type        = string
}

variable "google_client_id" {
  description = "Google OAuth Client ID"
  type        = string
}

variable "callback_urls" {
  description = "Allowed callback URLs for Cognito"
  type        = list(string)
}

variable "logout_urls" {
  description = "Allowed logout URLs for Cognito"
  type        = list(string)
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

variable "static_content_cdn_domain" {
  description = "CloudFront domain for static content (e.g. images.dev.cosmonaut-ai.com). Used by the custom_message Lambda for branded email assets."
  type        = string
  default     = ""
}
