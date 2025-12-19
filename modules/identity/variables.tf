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

