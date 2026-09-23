resource "aws_vpc" "this" {
  ipv4_ipam_pool_id                    = var.ipv4_ipam_pool_id
  ipv4_netmask_length                  = var.ipv4_netmask_length
  enable_dns_hostnames                 = true
  enable_dns_support                   = true
  enable_network_address_usage_metrics = true

  tags = local.common_tags

  lifecycle {
    precondition {
      condition     = length(setsubtract(toset(keys(var.transit_gateway_attachment_subnets)), toset(keys(var.availability_zones)))) == 0
      error_message = "transit_gateway_attachment_subnets keys must be existing availability_zones keys."
    }
  }
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

# TGW ENIs belong in a distinct subnet tier. This keeps attachment lifecycle,
# inspection routing, and app-subnet network policy independently reviewable.
resource "aws_subnet" "transit_gateway_attachment" {
  for_each = var.transit_gateway_attachment_subnets

  vpc_id                              = aws_vpc.this.id
  availability_zone                   = var.availability_zones[each.key].availability_zone
  cidr_block                          = local.transit_gateway_attachment_subnet_cidrs[each.key]
  map_public_ip_on_launch             = false
  private_dns_hostname_type_on_launch = "resource-name"

  tags = merge(local.common_tags, {
    Name = "${var.name}-${each.key}-transit"
    Tier = "transit"
  })
}

resource "aws_route_table" "transit_gateway_attachment" {
  for_each = aws_subnet.transit_gateway_attachment

  vpc_id = aws_vpc.this.id

  tags = merge(local.common_tags, {
    Name = "${var.name}-${each.key}-transit"
    Tier = "transit"
  })
}

resource "aws_route_table_association" "transit_gateway_attachment" {
  for_each = aws_subnet.transit_gateway_attachment

  subnet_id      = each.value.id
  route_table_id = aws_route_table.transit_gateway_attachment[each.key].id
}

resource "aws_route" "private_to_transit_gateway" {
  for_each = local.transit_gateway_route_entries

  route_table_id         = aws_route_table.private[each.value.route_table_key].id
  destination_cidr_block = var.transit_gateway_routes[each.value.route_key].destination_cidr_block
  transit_gateway_id     = var.transit_gateway_routes[each.value.route_key].transit_gateway_id
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
