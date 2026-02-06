output "s3_bucket_name" {
  description = "The images S3 bucket name"
  value       = aws_s3_bucket.images.id
}

output "s3_bucket_arn" {
  description = "The images S3 bucket ARN"
  value       = aws_s3_bucket.images.arn
}

output "cloudfront_domain_name" {
  description = "The CloudFront distribution domain name (for DNS CNAME target)"
  value       = aws_cloudfront_distribution.images.domain_name
}

output "cdn_domain_name" {
  description = "The custom domain for the images CDN"
  value       = var.domain_name
}
