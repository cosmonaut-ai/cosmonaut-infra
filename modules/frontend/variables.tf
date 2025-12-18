variable "env" {
  description = "The environment name (e.g., dev, prod)"
  type        = string
}

variable "domain_name" {
  description = "Domain name for the frontend"
  type        = string
}

variable "zone_id" {
  description = "Route53 Zone ID"
  type        = string
}

