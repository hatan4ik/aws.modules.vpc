output "interface_endpoint_ids" {
  description = "Interface endpoint IDs keyed by endpoint key."
  value       = { for key, endpoint in aws_vpc_endpoint.interface : key => endpoint.id }
}

output "interface_endpoint_dns_entries" {
  description = "DNS entries of each interface endpoint keyed by endpoint key."
  value       = { for key, endpoint in aws_vpc_endpoint.interface : key => endpoint.dns_entry }
}

output "gateway_endpoint_ids" {
  description = "Gateway endpoint IDs keyed by endpoint key."
  value       = { for key, endpoint in aws_vpc_endpoint.gateway : key => endpoint.id }
}

output "gateway_endpoint_prefix_list_ids" {
  description = "Managed prefix list IDs of gateway endpoints keyed by endpoint key, for security-group egress rules."
  value       = { for key, endpoint in aws_vpc_endpoint.gateway : key => endpoint.prefix_list_id }
}

output "security_group_id" {
  description = "ID of the created interface-endpoint security group, or null."
  value       = var.create_security_group ? aws_security_group.this[0].id : null
}

output "security_group_ids" {
  description = "Every security group attached to interface endpoints."
  value       = local.security_group_ids
}
