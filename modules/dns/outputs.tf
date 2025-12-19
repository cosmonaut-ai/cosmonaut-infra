output "zone_id" {
  description = "The Cloudflare Zone ID"
  value       = data.cloudflare_zone.domain.id
}

output "dns_record_id" {
  description = "The Cloudflare DNS record ID"
  value       = length(cloudflare_record.frontend) > 0 ? cloudflare_record.frontend[0].id : null
}

output "dns_record_hostname" {
  description = "The full hostname of the DNS record"
  value       = length(cloudflare_record.frontend) > 0 ? cloudflare_record.frontend[0].hostname : null
}

