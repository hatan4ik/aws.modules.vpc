locals {
  # These tags identify the module's single responsibility without duplicating caller-owned allocation tags.
  common_tags = merge(var.tags, {
    Name      = var.name
    Component = "workload-vpc"
  })

  private_subnet_cidrs = {
    for key, zone in var.availability_zones :
    key => cidrsubnet(aws_vpc.this.cidr_block, zone.subnet_newbits, zone.subnet_netnum)
  }

  transit_gateway_attachment_subnet_cidrs = {
    for key, subnet in var.transit_gateway_attachment_subnets :
    key => cidrsubnet(aws_vpc.this.cidr_block, subnet.subnet_newbits, subnet.subnet_netnum)
  }

  transit_gateway_route_entries = {
    for pair in setproduct(keys(aws_route_table.private), keys(var.transit_gateway_routes)) :
    "${pair[0]}:${pair[1]}" => {
      route_table_key = pair[0]
      route_key       = pair[1]
    }
  }

  flow_logs_assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "vpc-flow-logs.amazonaws.com" }
    }]
  })

  flow_logs_write_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogStream",
        "logs:DescribeLogStreams",
        "logs:PutLogEvents",
      ]
      Resource = "${aws_cloudwatch_log_group.flow_logs.arn}:*"
    }]
  })
}
