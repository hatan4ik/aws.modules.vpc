# An AWS IPAM hierarchy has one home-region administration plane, a
# non-allocating enterprise pool, and explicit allocatable Regional pools.
# Workload accounts receive only RAM access to their approved Regional pool.
#
# The cross-variable rules are preconditions on the IPAM itself: nothing in
# this module is created unless the home Region is an operating Region and
# every pool locale is one too.
resource "aws_vpc_ipam" "this" {
  description = "Private multi-Region IPAM for ${var.name}"
  tier        = "advanced"

  dynamic "operating_regions" {
    for_each = var.operating_regions

    content {
      region_name = operating_regions.value
    }
  }

  tags = local.common_tags

  lifecycle {
    precondition {
      condition     = contains(var.operating_regions, var.home_region)
      error_message = "operating_regions must include home_region because IPAM administration and RAM sharing occur there."
    }

    precondition {
      condition     = alltrue([for pool in values(var.regional_pools) : contains(var.operating_regions, pool.locale)])
      error_message = "Every regional_pools locale must be present in operating_regions."
    }
  }
}

# The top-level pool is deliberately not localized, so it reserves space and
# delegates only through its child pools. VPCs allocate solely from a Regional
# child pool.
resource "aws_vpc_ipam_pool" "top_level" {
  address_family = "ipv4"
  ipam_scope_id  = aws_vpc_ipam.this.private_default_scope_id
  description    = "Enterprise private address space for ${var.name}"

  tags = merge(local.common_tags, {
    Name  = "${var.name}-private"
    Scope = "enterprise"
  })
}

resource "aws_vpc_ipam_pool_cidr" "top_level" {
  ipam_pool_id = aws_vpc_ipam_pool.top_level.id
  cidr         = var.top_level_cidr
}

resource "aws_vpc_ipam_pool" "regional" {
  for_each = var.regional_pools

  address_family                    = "ipv4"
  ipam_scope_id                     = aws_vpc_ipam.this.private_default_scope_id
  source_ipam_pool_id               = aws_vpc_ipam_pool.top_level.id
  locale                            = each.value.locale
  description                       = "Regional private address space for ${var.name} in ${each.value.locale}"
  allocation_default_netmask_length = each.value.allocation_default_netmask_length
  allocation_min_netmask_length     = each.value.allocation_min_netmask_length
  allocation_max_netmask_length     = each.value.allocation_max_netmask_length
  allocation_resource_tags          = each.value.allocation_resource_tags

  tags = merge(local.common_tags, {
    Name   = "${var.name}-${each.key}"
    Locale = each.value.locale
    Scope  = "regional"
  })

  depends_on = [aws_vpc_ipam_pool_cidr.top_level]
}

resource "aws_vpc_ipam_pool_cidr" "regional" {
  for_each = var.regional_pools

  ipam_pool_id = aws_vpc_ipam_pool.regional[each.key].id
  cidr         = each.value.cidr
}

# AWS allows IPAM pool RAM shares only in the IPAM home Region. The calling
# root is pinned to that Region and this module requires it explicitly.
resource "aws_ram_resource_share" "regional_pool" {
  for_each = {
    for key, pool in var.regional_pools : key => pool
    if length(pool.ram_principals) > 0
  }

  name                      = "${var.name}-${each.key}-ipam-pool"
  allow_external_principals = false
  permission_arns           = ["arn:${local.partition}:ram::aws:permission/AWSRAMDefaultPermissionsIpamPool"]

  tags = merge(local.common_tags, {
    Name   = "${var.name}-${each.key}-ipam-pool"
    Locale = each.value.locale
  })

  depends_on = [aws_vpc_ipam_pool_cidr.regional]
}

resource "aws_ram_resource_association" "regional_pool" {
  for_each = aws_ram_resource_share.regional_pool

  resource_arn       = aws_vpc_ipam_pool.regional[each.key].arn
  resource_share_arn = each.value.arn
}

resource "aws_ram_principal_association" "regional_pool" {
  for_each = local.ram_principal_associations

  principal          = each.value.principal
  resource_share_arn = aws_ram_resource_share.regional_pool[each.value.pool_key].arn
}
