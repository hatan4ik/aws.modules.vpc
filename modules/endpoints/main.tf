# Interface endpoints share one security group that admits HTTPS from the VPC
# and nothing else; rules are standalone resources so ownership is unambiguous.

locals {
  security_group_name = coalesce(var.security_group_name, "${var.name}-interface-endpoints")
  security_group_ids = concat(
    var.create_security_group ? [aws_security_group.this[0].id] : [],
    sort(tolist(var.security_group_ids)),
  )
}

resource "aws_security_group" "this" {
  # checkov:skip=CKV2_AWS_5: The group is attached to every interface endpoint created below; Checkov's graph does not follow the endpoint's security_group_ids list.
  count = var.create_security_group ? 1 : 0

  name        = local.security_group_name
  description = var.security_group_description
  vpc_id      = var.vpc_id

  tags = merge(var.tags, { Name = local.security_group_name })

  lifecycle {
    precondition {
      condition     = length(var.vpc_cidr_blocks) > 0
      error_message = "vpc_cidr_blocks must list at least one CIDR when create_security_group is true."
    }
  }
}

# Keyed by position so an IPAM-allocated CIDR (unknown until apply) still
# yields known instance keys.
resource "aws_vpc_security_group_ingress_rule" "https" {
  for_each = { for index, cidr in var.vpc_cidr_blocks : tostring(index) => cidr if var.create_security_group }

  security_group_id = aws_security_group.this[0].id
  description       = "HTTPS from the VPC"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = each.value

  tags = merge(var.tags, { Name = "${local.security_group_name}-https-${each.key}" })
}

resource "aws_vpc_endpoint" "interface" {
  for_each = var.interface_endpoints

  vpc_id              = var.vpc_id
  vpc_endpoint_type   = "Interface"
  service_name        = each.value.service_name
  subnet_ids          = each.value.subnet_ids
  security_group_ids  = local.security_group_ids
  private_dns_enabled = each.value.private_dns_enabled
  policy              = each.value.policy_json
  ip_address_type     = each.value.ip_address_type

  dynamic "dns_options" {
    for_each = each.value.dns_record_ip_type == null && each.value.private_dns_only_for_inbound_resolver_endpoint == null ? [] : [each.value]

    content {
      dns_record_ip_type                             = dns_options.value.dns_record_ip_type
      private_dns_only_for_inbound_resolver_endpoint = dns_options.value.private_dns_only_for_inbound_resolver_endpoint
    }
  }

  tags = merge(var.tags, { Name = "${var.name}-${each.key}" })

  lifecycle {
    precondition {
      condition     = length(local.security_group_ids) > 0
      error_message = "Interface endpoints need at least one security group: keep create_security_group true or supply security_group_ids."
    }
  }
}

resource "aws_vpc_endpoint" "gateway" {
  for_each = var.gateway_endpoints

  vpc_id            = var.vpc_id
  vpc_endpoint_type = "Gateway"
  service_name      = each.value.service_name
  route_table_ids   = each.value.route_table_ids
  policy            = each.value.policy_json

  tags = merge(var.tags, { Name = "${var.name}-${each.key}" })
}
