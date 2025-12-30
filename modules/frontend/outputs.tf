output "cloudfront_domain_name" {
  description = "The CloudFront distribution domain name"
  value       = aws_cloudfront_distribution.frontend.domain_name
}

output "cloudfront_distribution_id" {
  description = "The CloudFront distribution ID"
  value       = aws_cloudfront_distribution.frontend.id
}

output "s3_bucket_name" {
  description = "The S3 bucket name"
  value       = aws_s3_bucket.frontend.id
}

output "acm_certificate_arn" {
  description = "The ARN of the ACM certificate"
  value       = aws_acm_certificate.cert.arn
}

output "acm_validation_records" {
  description = "ACM certificate validation records for DNS configuration"
  value = {
    # Deduplicate validation records by converting to a set first
    # When a cert has both root and wildcard, AWS often uses the same validation record
    for dvo in distinct([
      for d in aws_acm_certificate.cert.domain_validation_options : {
        name  = d.resource_record_name
        value = d.resource_record_value
        type  = d.resource_record_type
      }
    ]) : dvo.name => dvo
  }
}

output "api_cloudfront_domain_name" {
  value = aws_cloudfront_distribution.api.domain_name
}

output "waf_arn" {
  description = "The ARN of the WAF being used"
  value       = var.existing_waf_arn != null ? var.existing_waf_arn : aws_wafv2_web_acl.api_protection[0].arn
}

output "cloudfront_key_pair_id" {
  value = aws_cloudfront_public_key.main.id
}
