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

