# Internet access is a deliberate, declared choice: nothing here is created by
# the root unless the caller sets `internet`.

locals {
  created_eip_keys = { for key, gateway in var.nat_gateways : key => gateway if gateway.connectivity_type == "public" && gateway.allocation_id == null }
}

resource "aws_internet_gateway" "this" {
  count = var.create_internet_gateway ? 1 : 0

  vpc_id = var.vpc_id

  tags = merge(var.tags, { Name = "${var.name}-igw" })
}

resource "aws_egress_only_internet_gateway" "this" {
  count = var.create_egress_only_internet_gateway ? 1 : 0

  vpc_id = var.vpc_id

  tags = merge(var.tags, { Name = "${var.name}-eigw" })
}

resource "aws_eip" "nat" {
  for_each = local.created_eip_keys

  domain = "vpc"

  tags = merge(var.tags, { Name = "${var.name}-nat-${each.key}" })

  depends_on = [aws_internet_gateway.this]
}

resource "aws_nat_gateway" "this" {
  for_each = var.nat_gateways

  subnet_id         = each.value.subnet_id
  connectivity_type = each.value.connectivity_type
  allocation_id     = each.value.connectivity_type == "public" ? coalesce(each.value.allocation_id, try(aws_eip.nat[each.key].id, null)) : null
  private_ip        = each.value.private_ip

  tags = merge(var.tags, { Name = "${var.name}-nat-${each.key}" })

  lifecycle {
    precondition {
      condition     = each.value.connectivity_type == "private" || var.create_internet_gateway
      error_message = "A public NAT gateway needs the internet gateway: keep create_internet_gateway true."
    }
  }

  depends_on = [aws_internet_gateway.this]
}
