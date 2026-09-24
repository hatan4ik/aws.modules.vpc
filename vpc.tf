resource "aws_vpc" "this" {
  cidr_block          = var.cidr_block
  ipv4_ipam_pool_id   = var.ipam == null ? null : var.ipam.pool_id
  ipv4_netmask_length = var.ipam == null ? null : var.ipam.netmask_length

  instance_tenancy                     = var.instance_tenancy
  enable_dns_support                   = var.enable_dns_support
  enable_dns_hostnames                 = var.enable_dns_hostnames
  enable_network_address_usage_metrics = var.enable_network_address_usage_metrics

  tags = merge(var.tags, { Name = var.name })

  lifecycle {
    precondition {
      condition     = (var.cidr_block != null) != (var.ipam != null)
      error_message = "Declare exactly one of cidr_block or ipam."
    }

    precondition {
      condition     = length(setsubtract(toset(local.nat_subnet_refs), toset(local.subnet_refs))) == 0
      error_message = "Every internet.nat_gateways[*].subnet must name a declared <tier>/<az_key>."
    }

    precondition {
      condition     = length(setsubtract(toset(local.routes_needing_nat_keys), toset(local.nat_gateway_keys))) == 0
      error_message = "Every route nat_gateway_key must be a key of internet.nat_gateways."
    }

    precondition {
      condition     = !local.routes_needing_igw ? true : (local.internet_enabled ? var.internet.create_internet_gateway : false)
      error_message = "A route with internet_gateway = true needs internet.create_internet_gateway = true."
    }

    precondition {
      condition     = !local.routes_needing_eigw ? true : (local.internet_enabled ? var.internet.create_egress_only_internet_gateway : false)
      error_message = "A route with egress_only_internet_gateway = true needs internet.create_egress_only_internet_gateway = true."
    }

    precondition {
      condition     = length(setsubtract(toset(local.endpoint_tier_refs), toset(keys(var.subnets)))) == 0
      error_message = "Every endpoints subnet_tier and route_table_tiers entry must be a declared tier."
    }
  }
}

resource "aws_vpc_ipv4_cidr_block_association" "this" {
  for_each = var.secondary_cidr_blocks

  vpc_id     = aws_vpc.this.id
  cidr_block = each.value
}

resource "aws_vpc_encryption_control" "this" {
  count = var.vpc_encryption_control == null ? 0 : 1

  vpc_id = aws_vpc.this.id
  mode   = var.vpc_encryption_control

  tags = var.tags
}

# A new VPC starts with a permissive default security group. It is always
# managed here as deny-all so workloads must use purpose-specific groups.
resource "aws_default_security_group" "this" {
  vpc_id                 = aws_vpc.this.id
  revoke_rules_on_delete = true
  ingress                = []
  egress                 = []

  tags = merge(var.tags, { Name = "${var.name}-default-deny-all" })
}
