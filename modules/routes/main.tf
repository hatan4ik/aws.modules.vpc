# Every route is installed into every route table it is given, so a tier with
# one table per AZ gets identical routing in each AZ.

locals {
  entries = {
    for pair in setproduct(sort(keys(var.route_table_ids)), sort(keys(var.routes))) : "${pair[0]}/${pair[1]}" => {
      route_table_key = pair[0]
      route_key       = pair[1]
    }
  }

  default_destinations = ["0.0.0.0/0", "::/0"]
}

resource "aws_route" "this" {
  for_each = local.entries

  route_table_id = var.route_table_ids[each.value.route_table_key]

  destination_cidr_block      = var.routes[each.value.route_key].destination_cidr_block
  destination_ipv6_cidr_block = var.routes[each.value.route_key].destination_ipv6_cidr_block
  destination_prefix_list_id  = var.routes[each.value.route_key].destination_prefix_list_id

  transit_gateway_id        = var.routes[each.value.route_key].transit_gateway_id
  nat_gateway_id            = var.routes[each.value.route_key].nat_gateway_id
  gateway_id                = var.routes[each.value.route_key].gateway_id
  egress_only_gateway_id    = var.routes[each.value.route_key].egress_only_gateway_id
  vpc_peering_connection_id = var.routes[each.value.route_key].vpc_peering_connection_id
  network_interface_id      = var.routes[each.value.route_key].network_interface_id
  vpc_endpoint_id           = var.routes[each.value.route_key].vpc_endpoint_id
  core_network_arn          = var.routes[each.value.route_key].core_network_arn
  carrier_gateway_id        = var.routes[each.value.route_key].carrier_gateway_id
  local_gateway_id          = var.routes[each.value.route_key].local_gateway_id

  lifecycle {
    precondition {
      condition = var.allow_default_route || !contains(local.default_destinations, coalesce(
        var.routes[each.value.route_key].destination_cidr_block,
        var.routes[each.value.route_key].destination_ipv6_cidr_block,
        "prefix-list",
      ))
      error_message = "Default routes (0.0.0.0/0, ::/0) are rejected unless allow_default_route is true for the tier."
    }
  }
}
