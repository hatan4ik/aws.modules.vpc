# One subnet tier: subnets keyed by a stable AZ key, their route tables (one
# per subnet or one shared), and the associations. Routes are declared through
# modules/routes so a tier can route through gateways created after it.

locals {
  subnet_cidrs = {
    for key, zone in var.availability_zones : key =>
    zone.cidr_block != null ? zone.cidr_block : (var.vpc_cidr_block == null ? null : cidrsubnet(var.vpc_cidr_block, zone.newbits, zone.netnum))
  }

  route_table_keys = var.route_tables == "per_az" ? keys(var.availability_zones) : ["shared"]

  subnet_route_table_keys = {
    for key in keys(var.availability_zones) : key => var.route_tables == "per_az" ? key : "shared"
  }
}

resource "aws_subnet" "this" {
  for_each = var.availability_zones

  vpc_id                              = var.vpc_id
  availability_zone                   = each.value.availability_zone
  cidr_block                          = local.subnet_cidrs[each.key]
  map_public_ip_on_launch             = var.map_public_ip_on_launch
  private_dns_hostname_type_on_launch = var.private_dns_hostname_type_on_launch

  tags = merge(var.tags, {
    Name = "${var.name}-${var.tier}-${each.key}"
    Tier = var.tier
  })

  lifecycle {
    precondition {
      condition     = var.vpc_cidr_block != null || alltrue([for zone in values(var.availability_zones) : zone.cidr_block != null])
      error_message = "vpc_cidr_block is required when a subnet is allocated with newbits and netnum."
    }
  }
}

resource "aws_route_table" "this" {
  for_each = toset(local.route_table_keys)

  vpc_id = var.vpc_id

  tags = merge(var.tags, {
    Name = each.key == "shared" ? "${var.name}-${var.tier}" : "${var.name}-${var.tier}-${each.key}"
    Tier = var.tier
  })
}

resource "aws_route_table_association" "this" {
  for_each = var.availability_zones

  subnet_id      = aws_subnet.this[each.key].id
  route_table_id = aws_route_table.this[local.subnet_route_table_keys[each.key]].id
}
