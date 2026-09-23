output "vpc" {
  description = "The workload VPC identifiers and IPAM-assigned CIDR required by attachment and service modules."
  value = {
    id         = aws_vpc.this.id
    arn        = aws_vpc.this.arn
    cidr_block = aws_vpc.this.cidr_block
    cidr       = aws_vpc.this.cidr_block
  }
}

output "private_subnets" {
  description = "Stable AZ-keyed private subnet IDs, CIDRs, and route table IDs for workload composition."
  value = {
    for key, subnet in aws_subnet.private : key => {
      id                = subnet.id
      cidr_block        = subnet.cidr_block
      route_table_id    = aws_route_table.private[key].id
      az                = subnet.availability_zone
      availability_zone = subnet.availability_zone
    }
  }
}

output "transit_gateway_attachment_subnets" {
  description = "AZ-keyed dedicated transit subnet and route-table IDs for the workload-side VPC attachment module."
  value = {
    for key, subnet in aws_subnet.transit_gateway_attachment : key => {
      id                = subnet.id
      cidr_block        = subnet.cidr_block
      route_table_id    = aws_route_table.transit_gateway_attachment[key].id
      az                = subnet.availability_zone
      availability_zone = subnet.availability_zone
    }
  }
}

output "interface_endpoint_security_group_id" {
  description = "Security group ID applied to interface endpoints."
  value       = aws_security_group.interface_endpoints.id
}

output "interface_endpoint_ids" {
  description = "Stable endpoint-keyed interface endpoint IDs."
  value       = { for key, endpoint in aws_vpc_endpoint.interface : key => endpoint.id }
}

output "gateway_endpoint_ids" {
  description = "Stable endpoint-keyed gateway endpoint IDs."
  value       = { for key, endpoint in aws_vpc_endpoint.gateway : key => endpoint.id }
}

output "flow_log" {
  description = "VPC flow-log ID and encrypted CloudWatch log group ARN."
  value = {
    id              = aws_flow_log.this.id
    log_group_arn   = aws_cloudwatch_log_group.flow_logs.arn
    iam_role_arn    = aws_iam_role.flow_logs.arn
    encryption_mode = aws_vpc_encryption_control.this.mode
  }
}

output "flow_logs" {
  description = "Compatibility alias for flow_log with the canonical plural name used by the sandbox VPC module."
  value = {
    id              = aws_flow_log.this.id
    log_group_arn   = aws_cloudwatch_log_group.flow_logs.arn
    iam_role_arn    = aws_iam_role.flow_logs.arn
    encryption_mode = aws_vpc_encryption_control.this.mode
  }
}
