output "pinecone_key_arn" {
  value = aws_ssm_parameter.pinecone_key.arn
}

output "gemini_key_arn" {
  value = aws_ssm_parameter.gemini_key.arn
}

output "google_client_secret_arn" {
  value = aws_ssm_parameter.google_client_secret.arn
}

