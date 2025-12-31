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
  provider                  = aws.us_east_1
  domain_name               = var.domain_name
  subject_alternative_names = ["*.${var.domain_name}"]
  validation_method         = "DNS"

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

resource "aws_cloudfront_distribution" "frontend" {
  origin {
    domain_name              = aws_s3_bucket.frontend.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.frontend.id
    origin_id                = "S3-${aws_s3_bucket.frontend.bucket}"
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"

  aliases = [var.domain_name]

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${aws_s3_bucket.frontend.bucket}"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  # SPA Routing
  custom_error_response {
    error_code         = 403
    response_code      = 200
    response_page_path = "/index.html"
  }

  custom_error_response {
    error_code         = 404
    response_code      = 200
    response_page_path = "/index.html"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate_validation.cert.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  # Wait for certificate validation before creating distribution
  depends_on = [aws_acm_certificate_validation.cert]
}

resource "aws_s3_bucket_policy" "frontend" {
  bucket = aws_s3_bucket.frontend.id
  policy = data.aws_iam_policy_document.s3_policy.json
}

data "aws_iam_policy_document" "s3_policy" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.frontend.arn}/*"]

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.frontend.arn]
    }
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

resource "aws_cloudfront_function" "cors_preflight" {
  name    = "cosmonaut-${var.env}-cors-preflight"
  runtime = "cloudfront-js-1.0"
  comment = "Handle CORS preflight OPTIONS requests"
  publish = true
  code    = <<EOF
function handler(event) {
    var request = event.request;
    var headers = request.headers;
    var origin = headers.origin ? headers.origin.value : '';

    if (request.method === 'OPTIONS') {
        var response = {
            statusCode: 204,
            statusDescription: 'No Content',
            headers: {
                'access-control-allow-origin': { value: origin },
                'access-control-allow-methods': { value: 'GET, POST, PUT, DELETE, PATCH, OPTIONS' },
                'access-control-allow-headers': { value: 'Content-Type, Authorization, X-Amz-Date, X-Api-Key, X-Amz-Security-Token' },
                'access-control-allow-credentials': { value: 'true' },
                'access-control-max-age': { value: '300' }
            }
        };
        return response;
    }
    return request;
}
EOF
}

resource "aws_cloudfront_response_headers_policy" "api_cors" {
  name    = "cosmonaut-${var.env}-api-cors"
  comment = "CORS policy for API streaming"

  cors_config {
    access_control_allow_credentials = true

    access_control_allow_headers {
      items = ["Content-Type", "Authorization", "X-Amz-Date", "X-Api-Key", "X-Amz-Security-Token"]
    }

    access_control_allow_methods {
      items = ["GET", "OPTIONS", "POST", "PUT", "PATCH", "DELETE"]
    }

    access_control_allow_origins {
      items = var.cors_allowed_origins
    }

    origin_override = true
  }
}

resource "aws_cloudfront_distribution" "api" {
  enabled = true
  aliases = ["streaming.${var.domain_name}"]

  web_acl_id = var.existing_waf_arn != null ? var.existing_waf_arn : aws_wafv2_web_acl.api_protection[0].arn

  origin {
    domain_name = replace(replace(var.api_function_url, "https://", ""), "/", "")
    origin_id   = "LambdaOrigin"
    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  origin {
    domain_name              = aws_s3_bucket.frontend.bucket_regional_domain_name
    origin_id                = "S3Origin"
    origin_access_control_id = aws_cloudfront_origin_access_control.frontend.id
  }

  ordered_cache_behavior {
    path_pattern     = "/worlds/*/nodes/*/choose/*"
    target_origin_id = "LambdaOrigin"

    allowed_methods = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods  = ["GET", "HEAD"]

    # ENFORCE THE SIGNED COOKIES HERE
    trusted_key_groups = [aws_cloudfront_key_group.main.id]

    cache_policy_id            = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad" # Managed-CachingDisabled
    origin_request_policy_id   = "b689b0a8-53d0-40ab-baf2-68738e2966ac" # Managed-AllViewerExceptHost
    response_headers_policy_id = aws_cloudfront_response_headers_policy.api_cors.id
    viewer_protocol_policy     = "redirect-to-https"

    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.cors_preflight.arn
    }
  }

  default_cache_behavior {
    target_origin_id = "S3Origin" # Sends garbage traffic to S3 (403/404)
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    forwarded_values {
      query_string = false
      cookies { forward = "none" }
    }
    viewer_protocol_policy = "redirect-to-https"
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

# 1. Upload the Public Key to CloudFront
resource "aws_cloudfront_public_key" "main" {
  comment     = "Public key for signing cookies (${var.env})"
  encoded_key = file("${path.module}/public_key.pem")
  name        = "cosmonaut-${var.env}-key"
}

# 2. Create a Key Group (A list of keys that are allowed to sign)
resource "aws_cloudfront_key_group" "main" {
  comment = "Key group for API access"
  items   = [aws_cloudfront_public_key.main.id]
  name    = "cosmonaut-${var.env}-key-group"
}
