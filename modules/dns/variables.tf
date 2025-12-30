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
