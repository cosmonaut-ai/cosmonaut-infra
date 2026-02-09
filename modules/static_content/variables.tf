variable "env" {
  description = "The environment name (e.g., dev, prod)"
  type        = string
}

variable "domain_name" {
  description = "Custom domain for the static content CDN (e.g., images.dev.cosmonaut-ai.com)"
  type        = string
}

variable "acm_certificate_arn" {
  description = "ARN of the validated ACM wildcard certificate (must be in us-east-1)"
  type        = string
}

variable "cors_allowed_origins" {
  description = "List of allowed origins for CORS"
  type        = list(string)
}
