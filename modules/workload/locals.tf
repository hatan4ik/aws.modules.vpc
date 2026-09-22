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
