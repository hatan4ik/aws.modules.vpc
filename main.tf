# Composition root: one VPC and its tiers, gateways, routes, endpoints, and
# flow logs. Each submodule is a single-responsibility unit usable on its own.

module "subnets" {
  source   = "./modules/subnets"
  for_each = var.subnets

  vpc_id                              = aws_vpc.this.id
  vpc_cidr_block                      = aws_vpc.this.cidr_block
  name                                = var.name
  tier                                = each.key
  availability_zones                  = each.value.availability_zones
  route_tables                        = each.value.route_tables
  map_public_ip_on_launch             = each.value.map_public_ip_on_launch
  private_dns_hostname_type_on_launch = each.value.private_dns_hostname_type_on_launch
  tags                                = var.tags
}

module "internet" {
  source = "./modules/internet"
  count  = local.internet_enabled ? 1 : 0

  vpc_id                              = aws_vpc.this.id
  name                                = var.name
  create_internet_gateway             = var.internet.create_internet_gateway
  create_egress_only_internet_gateway = var.internet.create_egress_only_internet_gateway
  nat_gateways                        = local.nat_gateways
  tags                                = var.tags
}

module "routes" {
  source   = "./modules/routes"
  for_each = var.subnets

  route_table_ids     = module.subnets[each.key].route_table_ids
  routes              = local.resolved_routes[each.key]
  allow_default_route = each.value.allow_default_route
}

module "endpoints" {
  source = "./modules/endpoints"
  count  = local.endpoints_enabled ? 1 : 0

  vpc_id                     = aws_vpc.this.id
  name                       = var.name
  vpc_cidr_blocks            = local.vpc_cidr_blocks
  create_security_group      = var.endpoints.create_security_group
  security_group_name        = var.endpoints.security_group_name
  security_group_description = coalesce(var.endpoints.security_group_description, "Permits private HTTPS connections from this VPC to its AWS interface endpoints.")
  security_group_ids         = var.endpoints.security_group_ids
  tags                       = var.tags

  interface_endpoints = {
    for key, endpoint in var.endpoints.interface : key => {
      service_name                                   = endpoint.service_name
      subnet_ids                                     = toset(values(module.subnets[endpoint.subnet_tier].subnet_ids))
      private_dns_enabled                            = endpoint.private_dns_enabled
      policy_json                                    = endpoint.policy_json
      ip_address_type                                = endpoint.ip_address_type
      dns_record_ip_type                             = endpoint.dns_record_ip_type
      private_dns_only_for_inbound_resolver_endpoint = endpoint.private_dns_only_for_inbound_resolver_endpoint
    }
  }

  gateway_endpoints = {
    for key, endpoint in var.endpoints.gateway : key => {
      service_name    = endpoint.service_name
      route_table_ids = toset(flatten([for tier in endpoint.route_table_tiers : values(module.subnets[tier].route_table_ids)]))
      policy_json     = endpoint.policy_json
    }
  }
}

module "flow_logs" {
  source = "./modules/flow-logs"
  count  = local.flow_logs_enabled ? 1 : 0

  name                            = var.name
  vpc_id                          = aws_vpc.this.id
  destination                     = var.flow_logs.destination
  retention_in_days               = var.flow_logs.retention_in_days
  traffic_type                    = var.flow_logs.traffic_type
  max_aggregation_interval        = var.flow_logs.max_aggregation_interval
  log_format                      = var.flow_logs.log_format
  role_name                       = var.flow_logs.role_name
  role_path                       = var.flow_logs.role_path
  role_permissions_boundary       = var.flow_logs.role_permissions_boundary
  kms_key_deletion_window_in_days = var.flow_logs.kms_key_deletion_window_in_days
  partition                       = var.flow_logs.partition
  region                          = var.flow_logs.region
  account_id                      = var.flow_logs.account_id
  tags                            = var.tags
}
