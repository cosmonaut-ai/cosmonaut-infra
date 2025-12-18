output "api_endpoint" {
  value = aws_apigatewayv2_api.main.api_endpoint
}

output "lambda_role_arn" {
  value = aws_iam_role.lambda_exec.arn
}

