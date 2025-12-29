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

