output "user_pool_id" {
  value = aws_cognito_user_pool.main.id
}

output "user_pool_client_id" {
  value = aws_cognito_user_pool_client.main.id
}

output "cognito_user_pool_id" {
  value = aws_cognito_user_pool.main.id
}

output "cognito_user_pool_client_id" {
  value = aws_cognito_user_pool_client.main.id
}

output "cognito_user_pool_arn" {
  value = aws_cognito_user_pool.main.arn
}

output "user_pool_domain" {
  value = aws_cognito_user_pool_domain.main.domain
}

output "owner_group_name" {
  value = aws_cognito_user_group.owner.name
}

output "admin_group_name" {
  value = aws_cognito_user_group.admin.name
}
