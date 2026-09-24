output "vpc_id" {
  description = "ID of the VPC."
  value       = module.vpc.vpc_id
}

output "subnet_ids_by_tier" {
  description = "Subnet IDs keyed by tier then AZ key."
  value       = module.vpc.subnet_ids_by_tier
}

output "flow_log_group_name" {
  description = "CloudWatch log group that receives the VPC flow logs."
  value       = module.vpc.flow_log_group_name
}
