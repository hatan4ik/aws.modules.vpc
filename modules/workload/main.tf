resource "aws_vpc" "this" {
  ipv4_ipam_pool_id                    = var.ipv4_ipam_pool_id
  ipv4_netmask_length                  = var.ipv4_netmask_length
  enable_dns_hostnames                 = true
  enable_dns_support                   = true
  enable_network_address_usage_metrics = true

  tags = local.common_tags
}

resource "aws_vpc_encryption_control" "this" {
  vpc_id = aws_vpc.this.id
  mode   = "enforce"
}

resource "aws_default_security_group" "this" {
  vpc_id = aws_vpc.this.id

  ingress = []
  egress  = []

  tags = merge(local.common_tags, {
    Name = "${var.name}-default-deny"
  })
}

resource "aws_subnet" "private" {
  for_each = var.availability_zones

  vpc_id                              = aws_vpc.this.id
  availability_zone                   = each.value.availability_zone
  cidr_block                          = local.private_subnet_cidrs[each.key]
  map_public_ip_on_launch             = false
  private_dns_hostname_type_on_launch = "resource-name"

  tags = merge(local.common_tags, {
    Name = "${var.name}-${each.key}-private"
    Tier = "private"
  })
}

resource "aws_route_table" "private" {
  for_each = var.availability_zones

  vpc_id = aws_vpc.this.id

  tags = merge(local.common_tags, {
    Name = "${var.name}-${each.key}-private"
    Tier = "private"
  })
}

resource "aws_route_table_association" "private" {
  for_each = var.availability_zones

  subnet_id      = aws_subnet.private[each.key].id
  route_table_id = aws_route_table.private[each.key].id
}

resource "aws_security_group" "interface_endpoints" {
  name        = "${var.name}-interface-endpoints"
  description = "Permits private HTTPS connections from this VPC to its AWS interface endpoints."
  vpc_id      = aws_vpc.this.id

  ingress {
    description = "HTTPS from the IPAM allocated VPC range"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.this.cidr_block]
  }

  egress = []

  tags = merge(local.common_tags, {
    Name = "${var.name}-interface-endpoints"
  })
}

resource "aws_vpc_endpoint" "interface" {
  for_each = var.interface_endpoints

  vpc_id              = aws_vpc.this.id
  service_name        = each.value.service_name
  vpc_endpoint_type   = "Interface"
  subnet_ids          = values(aws_subnet.private)[*].id
  security_group_ids  = [aws_security_group.interface_endpoints.id]
  private_dns_enabled = each.value.private_dns_enabled
  policy              = try(each.value.policy_json, null)

  tags = merge(local.common_tags, {
    Name = "${var.name}-${each.key}"
  })
}

resource "aws_vpc_endpoint" "gateway" {
  for_each = var.gateway_endpoints

  vpc_id            = aws_vpc.this.id
  service_name      = each.value.service_name
  vpc_endpoint_type = "Gateway"
  route_table_ids   = values(aws_route_table.private)[*].id
  policy            = try(each.value.policy_json, null)

  tags = merge(local.common_tags, {
    Name = "${var.name}-${each.key}"
  })
}

resource "aws_cloudwatch_log_group" "flow_logs" {
  name              = "/aws/vpc/${var.name}/flow-logs"
  retention_in_days = var.flow_log_retention_in_days
  kms_key_id        = var.flow_log_kms_key_arn

  tags = local.common_tags
}

resource "aws_iam_role" "flow_logs" {
  name               = "${var.name}-vpc-flow-logs"
  assume_role_policy = local.flow_logs_assume_role_policy

  tags = local.common_tags
}

resource "aws_iam_role_policy" "flow_logs" {
  name   = "${var.name}-vpc-flow-logs-write"
  role   = aws_iam_role.flow_logs.id
  policy = local.flow_logs_write_policy
}

resource "aws_flow_log" "this" {
  iam_role_arn             = aws_iam_role.flow_logs.arn
  log_destination          = aws_cloudwatch_log_group.flow_logs.arn
  log_destination_type     = "cloud-watch-logs"
  traffic_type             = "ALL"
  vpc_id                   = aws_vpc.this.id
  max_aggregation_interval = 60

  tags = local.common_tags
}
