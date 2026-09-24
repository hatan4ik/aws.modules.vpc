output "vpc_id" {
  description = "ID of the VPC."
  value       = module.vpc.vpc_id
}

output "secondary_cidr_blocks" {
  description = "Secondary CIDR blocks associated with the VPC, sorted."
  value       = module.vpc.secondary_cidr_blocks
}

output "flow_log_id" {
  description = "ID of the flow log delivering to the supplied log group."
  value       = module.vpc.flow_log_id
}

output "flow_log_role_arn" {
  description = "ARN of the delivery role the module created for the supplied log group."
  value       = module.vpc.flow_log_role_arn
}

output "flow_log_group_name" {
  description = "Log group the flow logs are written to, exactly as supplied."
  value       = module.vpc.flow_log_group_name
}

output "flow_log_kms_key_arn" {
  description = "Key the log group is encrypted with, exactly as supplied."
  value       = module.vpc.flow_log_kms_key_arn
}
