variable "domain_name" {
  description = "The root domain name (e.g., cosmonaut-ai.com)"
  type        = string
}

variable "record_name" {
  description = "The DNS record name (e.g., @ for root, dev for subdomain)"
  type        = string
}

variable "cloudfront_domain_name" {
  description = "The CloudFront distribution domain name (optional, can be empty initially)"
  type        = string
  default     = ""
}

variable "acm_validation_records" {
  description = "Map of ACM certificate validation records"
  type = map(object({
    name  = string
    value = string
    type  = string
  }))
  default = {}
}

variable "api_cloudfront_domain_name" {
  type        = string
  description = "The CloudFront distribution domain name for streaming API"
}

variable "api_gateway_domain_name" {
  type        = string
  description = "The API Gateway regional domain name"
}

variable "api_record_name" {
  description = "Subdomain for the API (e.g., 'api' or 'api.dev')"
  type        = string
}

variable "streaming_record_name" {
  description = "Subdomain for the streaming API (e.g., 'streaming' or 'streaming.dev')"
  type        = string
}

variable "api_acm_validation_records" {
  description = "Map of ACM certificate validation records for the API"
  type = map(object({
    name  = string
    value = string
    type  = string
  }))
  default = {}
}

variable "static_content_record_name" {
  description = "Subdomain for the static content CDN (e.g., 'images' or 'images.dev')"
  type        = string
}

variable "static_content_cloudfront_domain_name" {
  description = "The CloudFront distribution domain name for the static content CDN"
  type        = string
}

# SES email variables
variable "ses_enabled" {
  description = "Whether SES email infrastructure is enabled (controls DNS record creation)"
  type        = bool
  default     = false
}

variable "ses_domain_verification_token" {
  description = "SES domain identity verification token for TXT record"
  type        = string
  default     = ""
}

variable "ses_dkim_tokens" {
  description = "DKIM tokens for SES domain authentication"
  type        = list(string)
  default     = []
}

variable "ses_mail_from_domain" {
  description = "The MAIL FROM subdomain for SES (e.g., mail.cosmonaut-ai.com)"
  type        = string
  default     = ""
}
