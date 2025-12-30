output "pinecone_key_arn" {
  value = aws_ssm_parameter.pinecone_key.arn
}

output "pinecone_key_name" {
  value = aws_ssm_parameter.pinecone_key.name
}

output "gemini_key_arn" {
  value = aws_ssm_parameter.gemini_key.arn
}

output "gemini_key_name" {
  value = aws_ssm_parameter.gemini_key.name
}

output "google_client_secret_arn" {
  value = aws_ssm_parameter.google_client_secret.arn
}

output "google_client_secret_name" {
  value = aws_ssm_parameter.google_client_secret.name
}

output "cloudfront_private_key_arn" {
  value = aws_ssm_parameter.cloudfront_private_key.arn
}

output "cloudfront_private_key_name" {
  value = aws_ssm_parameter.cloudfront_private_key.name
}
