output "api_endpoint" {
  value = aws_apigatewayv2_api.main.api_endpoint
}

output "lambda_role_arn" {
  value = aws_iam_role.lambda_exec.arn
}

output "fast_queue_url" {
  value = aws_sqs_queue.fast.id
}

output "fast_queue_arn" {
  value = aws_sqs_queue.fast.arn
}

output "slow_queue_url" {
  value = aws_sqs_queue.slow.id
}

output "slow_queue_arn" {
  value = aws_sqs_queue.slow.arn
}

output "fast_dlq_url" {
  value = aws_sqs_queue.fast_dlq.id
}

output "fast_dlq_arn" {
  value = aws_sqs_queue.fast_dlq.arn
}

output "slow_dlq_url" {
  value = aws_sqs_queue.slow_dlq.id
}

output "slow_dlq_arn" {
  value = aws_sqs_queue.slow_dlq.arn
}

output "api_function_url" {
  description = "The Function URL endpoint for the API Lambda (Used for streaming responses)"
  value       = aws_lambda_function_url.api.function_url
}

output "api_gateway_domain_name" {
  description = "The regional domain name for the API Gateway"
  value       = aws_apigatewayv2_domain_name.api.domain_name_configuration[0].target_domain_name
}

output "api_acm_validation_records" {
  description = "ACM certificate validation records for the API Gateway"
  value = {
    for dvo in aws_acm_certificate.api.domain_validation_options : dvo.domain_name => {
      name  = dvo.resource_record_name
      value = dvo.resource_record_value
      type  = dvo.resource_record_type
    }
  }
}
