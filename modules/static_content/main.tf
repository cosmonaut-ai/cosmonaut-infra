# S3 bucket for generated static content (images, audio, etc.)
resource "aws_s3_bucket" "static_content" {
  bucket = "cosmonaut-ai-${var.env}-images" # Keep original bucket name to avoid data loss
}

resource "aws_s3_bucket_public_access_block" "static_content" {
  bucket = aws_s3_bucket.static_content.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "static_content" {
  bucket = aws_s3_bucket.static_content.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256" # SSE-S3
    }
  }
}

# OAC for CloudFront -> S3 access
resource "aws_cloudfront_origin_access_control" "static_content" {
  name                              = "cosmonaut-${var.env}-images-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# CORS response headers for static content requests from frontend
resource "aws_cloudfront_response_headers_policy" "static_content_cors" {
  name    = "cosmonaut-${var.env}-images-cors"
  comment = "CORS policy for static content (images, audio)"

  cors_config {
    access_control_allow_credentials = false

    access_control_allow_headers {
      items = ["*"]
    }

    access_control_allow_methods {
      items = ["GET", "HEAD"]
    }

    access_control_allow_origins {
      items = var.cors_allowed_origins
    }

    origin_override = true
  }
}

# CloudFront distribution for serving static content
resource "aws_cloudfront_distribution" "static_content" {
  origin {
    domain_name              = aws_s3_bucket.static_content.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.static_content.id
    origin_id                = "S3-${aws_s3_bucket.static_content.bucket}"
  }

  enabled         = true
  is_ipv6_enabled = true

  aliases = [var.domain_name]

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${aws_s3_bucket.static_content.bucket}"

    cache_policy_id            = "658327ea-f89d-4fab-a63d-7e88639e58f6" # Managed-CachingOptimized
    response_headers_policy_id = aws_cloudfront_response_headers_policy.static_content_cors.id
    viewer_protocol_policy     = "redirect-to-https"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = var.acm_certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }
}

# Allow CloudFront to read from the S3 bucket via OAC
resource "aws_s3_bucket_policy" "static_content" {
  bucket = aws_s3_bucket.static_content.id
  policy = data.aws_iam_policy_document.static_content_bucket_policy.json
}

data "aws_iam_policy_document" "static_content_bucket_policy" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.static_content.arn}/*"]

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.static_content.arn]
    }
  }
}

# Moved blocks to prevent resource destruction during rename
moved {
  from = aws_s3_bucket.images
  to   = aws_s3_bucket.static_content
}

moved {
  from = aws_s3_bucket_public_access_block.images
  to   = aws_s3_bucket_public_access_block.static_content
}

moved {
  from = aws_s3_bucket_server_side_encryption_configuration.images
  to   = aws_s3_bucket_server_side_encryption_configuration.static_content
}

moved {
  from = aws_cloudfront_origin_access_control.images
  to   = aws_cloudfront_origin_access_control.static_content
}

moved {
  from = aws_cloudfront_response_headers_policy.images_cors
  to   = aws_cloudfront_response_headers_policy.static_content_cors
}

moved {
  from = aws_cloudfront_distribution.images
  to   = aws_cloudfront_distribution.static_content
}

moved {
  from = aws_s3_bucket_policy.images
  to   = aws_s3_bucket_policy.static_content
}
