terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }
}

# Data source to get the Cloudflare zone
data "cloudflare_zone" "domain" {
  name = var.domain_name
}

# DNS record for the main domain pointing to CloudFront
# 
# IMPORTANT: Due to Terraform's dependency resolution, this resource requires a two-stage apply:
# 1. First apply: Create certificate and validation records (use: terraform apply -target=module.frontend.aws_acm_certificate.cert -target=module.dns.cloudflare_record.cert_validation)
# 2. Second apply: Create CloudFront and frontend DNS record (use: terraform apply)
#
# This is because cloudfront_domain_name is unknown until CloudFront is created, and Terraform
# cannot conditionally create resources based on unknown values.
resource "cloudflare_record" "frontend" {
  # Use count=1 always, but the resource will only be created when cloudfront_domain_name has a value
  # Terraform will defer creation until the value is known
  count = 1

  zone_id = data.cloudflare_zone.domain.id
  name    = var.record_name
  content = var.cloudfront_domain_name
  type    = "CNAME"
  ttl     = 1     # Auto TTL
  proxied = false # Must be false for CloudFront to work with custom SSL
}

# DNS records for ACM certificate validation
resource "cloudflare_record" "cert_validation" {
  for_each = merge(var.acm_validation_records, var.api_acm_validation_records)

  zone_id = data.cloudflare_zone.domain.id
  name    = each.value.name
  content = each.value.value
  type    = each.value.type
  ttl     = 60
  proxied = false
}

resource "cloudflare_record" "api" {
  zone_id = data.cloudflare_zone.domain.id
  name    = var.api_record_name
  content = var.api_gateway_domain_name
  type    = "CNAME"
  proxied = false
  ttl     = 1
}

resource "cloudflare_record" "streaming" {
  zone_id = data.cloudflare_zone.domain.id
  name    = var.streaming_record_name
  content = var.api_cloudfront_domain_name
  type    = "CNAME"
  proxied = false
  ttl     = 1
}

resource "cloudflare_record" "static_content" {
  zone_id = data.cloudflare_zone.domain.id
  name    = var.static_content_record_name
  content = var.static_content_cloudfront_domain_name
  type    = "CNAME"
  proxied = false
  ttl     = 1
}

moved {
  from = cloudflare_record.images
  to   = cloudflare_record.static_content
}
