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

variable "api_lambda_arn" {
  description = "ARN of the shared Lambda function (used by API and SQS worker handler)"
  type        = string
}

variable "slow_worker_lambda_arn" {
  description = "ARN of the slow worker Lambda function"
  type        = string
}

variable "fast_worker_lambda_arn" {
  description = "ARN of the fast worker Lambda function"
  type        = string
}
