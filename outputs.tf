output "vpc_id" {
  description = "VPC ID."
  value       = aws_vpc.this.id
}

output "vpc_arn" {
  description = "VPC ARN."
  value       = aws_vpc.this.arn
}

output "cidr_block" {
  description = "Primary IPv4 CIDR (known after apply for IPAM allocations)."
  value       = aws_vpc.this.cidr_block
}

output "secondary_cidr_blocks" {
  description = "Secondary IPv4 CIDR blocks associated with the VPC."
  value       = sort(tolist(var.secondary_cidr_blocks))
}

output "default_security_group_id" {
  description = "ID of the managed deny-all default security group."
  value       = aws_default_security_group.this.id
}

output "encryption_control_mode" {
  description = "VPC Encryption Control mode, or null when unmanaged."
  value       = var.vpc_encryption_control
}

output "subnets" {
  description = "Subnets keyed by tier then AZ key: id, arn, cidr_block, availability_zone, route_table_id."
  value       = { for tier, subnets in module.subnets : tier => subnets.subnets }
}

output "subnet_ids_by_tier" {
  description = "Subnet IDs keyed by tier then AZ key."
  value       = { for tier, subnets in module.subnets : tier => subnets.subnet_ids }
}

output "subnet_cidr_blocks_by_tier" {
  description = "Subnet CIDR blocks keyed by tier then AZ key (known at plan time for explicit CIDRs)."
  value       = { for tier, subnets in module.subnets : tier => subnets.subnet_cidr_blocks }
}

output "route_table_ids_by_tier" {
  description = "Route table IDs keyed by tier then AZ key (or shared)."
  value       = { for tier, subnets in module.subnets : tier => subnets.route_table_ids }
}

output "internet_gateway_id" {
  description = "Internet gateway ID, or null."
  value       = local.internet_enabled ? module.internet[0].internet_gateway_id : null
}

output "egress_only_internet_gateway_id" {
  description = "Egress-only internet gateway ID, or null."
  value       = local.internet_enabled ? module.internet[0].egress_only_internet_gateway_id : null
}

output "nat_gateway_ids" {
  description = "NAT gateway IDs keyed by gateway key."
  value       = local.internet_enabled ? module.internet[0].nat_gateway_ids : {}
}

output "nat_gateway_public_ips" {
  description = "Public IPs of public NAT gateways keyed by gateway key."
  value       = local.internet_enabled ? module.internet[0].nat_gateway_public_ips : {}
}

output "interface_endpoint_ids" {
  description = "Interface endpoint IDs keyed by endpoint key."
  value       = local.endpoints_enabled ? module.endpoints[0].interface_endpoint_ids : {}
}

output "gateway_endpoint_ids" {
  description = "Gateway endpoint IDs keyed by endpoint key."
  value       = local.endpoints_enabled ? module.endpoints[0].gateway_endpoint_ids : {}
}

output "gateway_endpoint_prefix_list_ids" {
  description = "Managed prefix list IDs of gateway endpoints keyed by endpoint key."
  value       = local.endpoints_enabled ? module.endpoints[0].gateway_endpoint_prefix_list_ids : {}
}

output "endpoint_security_group_id" {
  description = "ID of the interface-endpoint security group, or null."
  value       = local.endpoints_enabled ? module.endpoints[0].security_group_id : null
}

output "flow_log_id" {
  description = "Flow log ID, or null."
  value       = local.flow_logs_enabled ? module.flow_logs[0].id : null
}

output "flow_log_group_name" {
  description = "Flow-log CloudWatch log group name, or null."
  value       = local.flow_logs_enabled ? module.flow_logs[0].log_group_name : null
}

output "flow_log_group_arn" {
  description = "Flow-log CloudWatch log group ARN, or null."
  value       = local.flow_logs_enabled ? module.flow_logs[0].log_group_arn : null
}

output "flow_log_kms_key_arn" {
  description = "KMS key encrypting the flow-log log group, or null."
  value       = local.flow_logs_enabled ? module.flow_logs[0].kms_key_arn : null
}

output "flow_log_role_arn" {
  description = "Flow-log delivery role ARN, or null."
  value       = local.flow_logs_enabled ? module.flow_logs[0].role_arn : null
}

output "flow_log_role_name" {
  description = "Flow-log delivery role name, or null."
  value       = local.flow_logs_enabled ? module.flow_logs[0].role_name : null
}

# Compatibility outputs shaped like the v0.1.x root so existing roots keep
# their own output contracts unchanged.

output "vpc" {
  description = "VPC identifiers in the v0.1.x shape: id, arn, cidr."
  value = {
    id   = aws_vpc.this.id
    arn  = aws_vpc.this.arn
    cidr = aws_vpc.this.cidr_block
  }
}

output "private_subnets" {
  description = "The private tier in the v0.1.x shape (id, availability_zone, cidr, route_table_id by AZ key); empty when no private tier exists."
  value = contains(keys(var.subnets), "private") ? {
    for key, subnet in module.subnets["private"].subnets : key => {
      id                = subnet.id
      availability_zone = subnet.availability_zone
      cidr              = subnet.cidr_block
      route_table_id    = subnet.route_table_id
    }
  } : {}
}

output "flow_logs" {
  description = "Flow-log identifiers in the v0.1.x shape (id, log_group_name, kms_key_arn, role_arn), or null when disabled."
  value = local.flow_logs_enabled ? {
    id             = module.flow_logs[0].id
    log_group_name = module.flow_logs[0].log_group_name
    kms_key_arn    = module.flow_logs[0].kms_key_arn
    role_arn       = module.flow_logs[0].role_arn
  } : null
}
