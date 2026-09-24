output "vpc_id" {
  description = "ID of the VPC."
  value       = module.vpc.vpc_id
}

output "internet_gateway_id" {
  description = "ID of the internet gateway the public tier routes through."
  value       = module.vpc.internet_gateway_id
}

output "nat_gateway_public_ips" {
  description = "Public IP of each NAT gateway keyed by gateway key; the source address of outbound traffic from the private tier."
  value       = module.vpc.nat_gateway_public_ips
}

output "subnet_ids_by_tier" {
  description = "Subnet IDs keyed by tier then AZ key."
  value       = module.vpc.subnet_ids_by_tier
}

output "route_table_ids_by_tier" {
  description = "Route table IDs keyed by tier then AZ key."
  value       = module.vpc.route_table_ids_by_tier
}
