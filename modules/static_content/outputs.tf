output "s3_bucket_name" {
  description = "The static content S3 bucket name"
  value       = aws_s3_bucket.static_content.id
}

output "s3_bucket_arn" {
  description = "The static content S3 bucket ARN"
  value       = aws_s3_bucket.static_content.arn
}

output "cloudfront_domain_name" {
  description = "The CloudFront distribution domain name (for DNS CNAME target)"
  value       = aws_cloudfront_distribution.static_content.domain_name
}

output "cdn_domain_name" {
  description = "The custom domain for the static content CDN"
  value       = var.domain_name
}
