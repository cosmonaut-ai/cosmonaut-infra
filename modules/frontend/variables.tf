variable "env" {
  description = "The environment name (e.g., dev, prod)"
  type        = string
}

variable "domain_name" {
  description = "Domain name for the frontend"
  type        = string
}

variable "api_function_url" {
  description = "The Function URL endpoint for the API Lambda (Used for streaming responses)"
  type        = string
}
