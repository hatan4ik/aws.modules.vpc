output "subnets" {
  description = "Subnets keyed by AZ key: id, arn, cidr_block, availability_zone, route_table_id."
  value = {
    for key, subnet in aws_subnet.this : key => {
      id                = subnet.id
      arn               = subnet.arn
      cidr_block        = subnet.cidr_block
      availability_zone = subnet.availability_zone
      route_table_id    = aws_route_table.this[local.subnet_route_table_keys[key]].id
    }
  }
}

output "subnet_ids" {
  description = "Subnet IDs keyed by AZ key."
  value       = { for key, subnet in aws_subnet.this : key => subnet.id }
}

output "subnet_cidr_blocks" {
  description = "Subnet CIDR blocks keyed by AZ key, known at plan time."
  value       = local.subnet_cidrs
}

output "route_table_ids" {
  description = "Route table IDs keyed by AZ key (per_az) or by \"shared\"."
  value       = { for key, table in aws_route_table.this : key => table.id }
}

output "tier" {
  description = "Tier identifier of these subnets."
  value       = var.tier
}
