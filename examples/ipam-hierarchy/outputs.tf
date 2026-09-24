output "delegated_admin_account_id" {
  description = "Account recorded by the management account as the delegated VPC IPAM administrator."
  value       = module.ipam_organization_admin.delegated_admin.account_id
}

output "ipam_id" {
  description = "ID of the IPAM."
  value       = module.ipam.ipam.id
}

output "private_default_scope_id" {
  description = "Private scope that every pool belongs to."
  value       = module.ipam.ipam.private_default_scope_id
}

output "regional_pool_ids" {
  description = "Regional pool IDs keyed by pool key; the values workload VPCs pass as ipam.pool_id."
  value       = { for key, pool in module.ipam.regional_pools : key => pool.id }
}

output "regional_pools" {
  description = "Regional pools keyed by pool key: id, arn, locale, cidr, and the RAM share ARN when shared."
  value       = module.ipam.regional_pools
}
