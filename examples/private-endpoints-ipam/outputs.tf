output "vpc_id" {
  description = "ID of the VPC."
  value       = module.vpc.vpc_id
}

output "cidr_block" {
  description = "Primary CIDR allocated from the IPAM pool; known after apply."
  value       = module.vpc.cidr_block
}

output "subnets" {
  description = "Subnets keyed by tier then AZ key: id, arn, cidr_block, availability_zone, route_table_id."
  value       = module.vpc.subnets
}

output "interface_endpoint_ids" {
  description = "Interface endpoint IDs keyed by endpoint key (ecr-api, ecr-dkr, logs, sts)."
  value       = module.vpc.interface_endpoint_ids
}

output "gateway_endpoint_ids" {
  description = "Gateway endpoint IDs keyed by endpoint key (s3)."
  value       = module.vpc.gateway_endpoint_ids
}

output "endpoint_security_group_id" {
  description = "Security group attached to every interface endpoint; admits HTTPS from the VPC only."
  value       = module.vpc.endpoint_security_group_id
}
