output "vpc" {
  description = "VPC identifiers and CIDR available for separately reviewed attachments."
  value = {
    id   = aws_vpc.this.id
    arn  = aws_vpc.this.arn
    cidr = aws_vpc.this.cidr_block
  }
}

output "private_subnets" {
  description = "Private subnet IDs and placement keyed by stable subnet name."
  value = {
    for key, subnet in aws_subnet.private : key => {
      id                = subnet.id
      availability_zone = subnet.availability_zone
      cidr              = subnet.cidr_block
      route_table_id    = aws_route_table.private[key].id
    }
  }
}

output "flow_logs" {
  description = "VPC Flow Logs identifiers for observability configuration."
  value = {
    id             = aws_flow_log.vpc.id
    log_group_name = aws_cloudwatch_log_group.flow_logs.name
    kms_key_arn    = aws_kms_key.flow_logs.arn
    role_arn       = aws_iam_role.flow_logs.arn
  }
}
