variable "env" {
  description = "The environment name (e.g., dev, prod)"
  type        = string
}

variable "dynamodb_table_arn" {
  description = "ARN of the DynamoDB table"
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

variable "cors_allowed_origins" {
  description = "List of allowed origins for CORS"
  type        = list(string)
}

variable "mock_auth" {
  description = "Whether to mock authentication"
  type        = bool
  default     = false
}
