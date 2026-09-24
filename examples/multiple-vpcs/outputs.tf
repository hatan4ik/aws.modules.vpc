output "vpc_ids" {
  description = "VPC IDs keyed by VPC key."
  value       = { for key, vpc in module.vpc : key => vpc.vpc_id }
}

output "subnet_ids_by_tier" {
  description = "Subnet IDs keyed by VPC key, then tier, then AZ key."
  value       = { for key, vpc in module.vpc : key => vpc.subnet_ids_by_tier }
}

output "route_table_ids_by_tier" {
  description = "Route table IDs keyed by VPC key, then tier, then AZ key; the tables to add routes to when the VPCs are connected."
  value       = { for key, vpc in module.vpc : key => vpc.route_table_ids_by_tier }
}
