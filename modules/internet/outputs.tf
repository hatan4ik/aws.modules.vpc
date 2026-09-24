output "internet_gateway_id" {
  description = "Internet gateway ID, or null."
  value       = var.create_internet_gateway ? aws_internet_gateway.this[0].id : null
}

output "egress_only_internet_gateway_id" {
  description = "Egress-only internet gateway ID, or null."
  value       = var.create_egress_only_internet_gateway ? aws_egress_only_internet_gateway.this[0].id : null
}

output "nat_gateway_ids" {
  description = "NAT gateway IDs keyed by gateway key."
  value       = { for key, gateway in aws_nat_gateway.this : key => gateway.id }
}

output "nat_gateway_public_ips" {
  description = "Public IPs of public NAT gateways keyed by gateway key."
  value       = { for key, gateway in aws_nat_gateway.this : key => gateway.public_ip if var.nat_gateways[key].connectivity_type == "public" }
}

output "eip_allocation_ids" {
  description = "Allocation IDs of the Elastic IPs created for NAT gateways, keyed by gateway key."
  value       = { for key, eip in aws_eip.nat : key => eip.id }
}
