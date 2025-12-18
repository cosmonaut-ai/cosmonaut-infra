variable "env" {
  description = "The environment name (e.g., dev, prod)"
  type        = string
}

variable "google_client_id" {
  description = "Google OAuth Client ID"
  type        = string
}

variable "google_client_secret" {
  description = "Google OAuth Client Secret (retrieved from SSM)"
  type        = string
  sensitive   = true
}

variable "callback_urls" {
  description = "Allowed callback URLs for Cognito"
  type        = list(string)
}

variable "logout_urls" {
  description = "Allowed logout URLs for Cognito"
  type        = list(string)
}

