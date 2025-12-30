resource "aws_s3_bucket" "frontend" {
  bucket = "cosmonaut-${var.env}-frontend"
}

resource "aws_s3_bucket_public_access_block" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_cloudfront_origin_access_control" "frontend" {
  name                              = "cosmonaut-${var.env}-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# CloudFront requires ACM certificates to be in us-east-1
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

resource "aws_acm_certificate" "cert" {
  provider          = aws.us_east_1
  domain_name       = var.domain_name
  validation_method = "DNS"

  subject_alternative_names = ["*.${var.domain_name}"]

  lifecycle {
    create_before_destroy = true
  }
}

# Note: Certificate validation records are output for DNS module to create
# The certificate validation resource waits for DNS validation to complete
# This ensures the certificate is fully validated before CloudFront uses it
resource "aws_acm_certificate_validation" "cert" {
  provider        = aws.us_east_1
  certificate_arn = aws_acm_certificate.cert.arn

  # Wait for DNS validation records to be created (they're created by the DNS module)
  # This will wait for validation to complete before proceeding
  timeouts {
    create = "5m"
  }
}


variable "existing_waf_arn" {
  description = "ARN of an existing WAF to reuse (saves $5/mo). If null, a new WAF is created."
  type        = string
  default     = null
}

# WAF to protect the API from DDoS / High Costs
resource "aws_wafv2_web_acl" "api_protection" {
  count = var.existing_waf_arn == null ? 1 : 0 # <--- The Toggle switch

  name        = "cosmonaut-api-waf"
  description = "Rate limiting for API Lambda"
  scope       = "CLOUDFRONT"
  provider    = aws.us_east_1

  default_action {
    allow {}
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "cosmonaut-api-waf"
    sampled_requests_enabled   = true
  }

  rule {
    name     = "RateLimit"
    priority = 1
    action {
      block {}
    }
    statement {
      rate_based_statement {
        limit              = 500 # Limit: 500 requests per 5 mins per IP
        aggregate_key_type = "IP"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "RateLimit"
      sampled_requests_enabled   = true
    }
  }
}

resource "aws_cloudfront_distribution" "api" {
  enabled = true
  # We will use the wildcard cert, so we need an alias.
  # Note: The actual alias is passed in via variable or derived. 
  # For simplicity, we assume api.domain or api-dev.domain based on the cert.
  # To avoid circular dependency logic, we usually pass the desired 'api_domain_name' as a var, 
  # but here we can derive it if you stick to a standard pattern:
  aliases = ["api.${var.domain_name}"]

  web_acl_id = var.existing_waf_arn != null ? var.existing_waf_arn : aws_wafv2_web_acl.api_protection[0].arn

  origin {
    # Strip protocol for CloudFront
    domain_name = replace(replace(var.api_function_url, "https://", ""), "/", "")
    origin_id   = "LambdaOrigin"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  default_cache_behavior {
    allowed_methods        = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "LambdaOrigin"
    viewer_protocol_policy = "redirect-to-https"

    # 1. Disable Caching
    cache_policy_id = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad" # Managed-CachingDisabled

    # 2. Forward Origin headers (Critical for Lambda URL)
    origin_request_policy_id = "b689b0a8-53d0-40ab-baf2-68738e2966ac" # Managed-AllViewerExceptHostHeader
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate_validation.cert.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
}
