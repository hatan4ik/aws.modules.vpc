locals {
  internet_enabled  = var.internet != null
  endpoints_enabled = var.endpoints != null
  flow_logs_enabled = var.flow_logs != null

  vpc_cidr_blocks = concat([aws_vpc.this.cidr_block], sort(tolist(var.secondary_cidr_blocks)))

  # NAT gateways reference their subnet as <tier>/<az_key>; resolve to IDs.
  nat_gateways = local.internet_enabled ? {
    for key, gateway in var.internet.nat_gateways : key => {
      subnet_id         = module.subnets[split("/", gateway.subnet)[0]].subnet_ids[split("/", gateway.subnet)[1]]
      allocation_id     = gateway.allocation_id
      connectivity_type = gateway.connectivity_type
      private_ip        = gateway.private_ip
    }
  } : {}

  # Route targets that name gateways created here are resolved to IDs before
  # the routes module sees them, so it stays a pure ID-based unit.
  resolved_routes = {
    for tier, spec in var.subnets : tier => {
      for key, route in spec.routes : key => {
        destination_cidr_block      = route.destination_cidr_block
        destination_ipv6_cidr_block = route.destination_ipv6_cidr_block
        destination_prefix_list_id  = route.destination_prefix_list_id
        transit_gateway_id          = route.transit_gateway_id
        nat_gateway_id              = route.nat_gateway_key != null ? module.internet[0].nat_gateway_ids[route.nat_gateway_key] : route.nat_gateway_id
        gateway_id                  = route.internet_gateway ? module.internet[0].internet_gateway_id : route.gateway_id
        egress_only_gateway_id      = route.egress_only_internet_gateway ? module.internet[0].egress_only_internet_gateway_id : route.egress_only_gateway_id
        vpc_peering_connection_id   = route.vpc_peering_connection_id
        network_interface_id        = route.network_interface_id
        vpc_endpoint_id             = route.vpc_endpoint_id
        core_network_arn            = route.core_network_arn
        carrier_gateway_id          = route.carrier_gateway_id
        local_gateway_id            = route.local_gateway_id
      }
    }
  }

  # Validation helpers (plan-time known).
  nat_gateway_keys = local.internet_enabled ? keys(var.internet.nat_gateways) : []
  nat_subnet_refs  = local.internet_enabled ? [for gateway in values(var.internet.nat_gateways) : gateway.subnet] : []
  subnet_refs      = flatten([for tier, spec in var.subnets : [for az in keys(spec.availability_zones) : "${tier}/${az}"]])

  routes_needing_nat_keys = flatten([for spec in values(var.subnets) : [for route in values(spec.routes) : route.nat_gateway_key if route.nat_gateway_key != null]])
  routes_needing_igw      = anytrue(flatten([for spec in values(var.subnets) : [for route in values(spec.routes) : route.internet_gateway]]))
  routes_needing_eigw     = anytrue(flatten([for spec in values(var.subnets) : [for route in values(spec.routes) : route.egress_only_internet_gateway]]))

  endpoint_tier_refs = local.endpoints_enabled ? concat(
    [for endpoint in values(var.endpoints.interface) : endpoint.subnet_tier],
    flatten([for endpoint in values(var.endpoints.gateway) : tolist(endpoint.route_table_tiers)]),
  ) : []

  single_az_tiers = [for tier, spec in var.subnets : tier if length(spec.availability_zones) < 2]
}
