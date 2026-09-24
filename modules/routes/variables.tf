variable "route_table_ids" {
  description = "Route tables that receive every route, keyed by a stable identifier (typically the AZ key or \"shared\")."
  type        = map(string)
  nullable    = false

  validation {
    condition     = alltrue([for id in values(var.route_table_ids) : can(regex("^rtb-[0-9a-f]+$", id))])
    error_message = "Every route_table_ids value must be a route table ID (rtb-...)."
  }
}

variable "routes" {
  description = "Routes keyed by a stable identifier. Each names exactly one destination (destination_cidr_block, destination_ipv6_cidr_block, or destination_prefix_list_id) and exactly one target."
  type = map(object({
    destination_cidr_block      = optional(string)
    destination_ipv6_cidr_block = optional(string)
    destination_prefix_list_id  = optional(string)
    transit_gateway_id          = optional(string)
    nat_gateway_id              = optional(string)
    gateway_id                  = optional(string)
    egress_only_gateway_id      = optional(string)
    vpc_peering_connection_id   = optional(string)
    network_interface_id        = optional(string)
    vpc_endpoint_id             = optional(string)
    core_network_arn            = optional(string)
    carrier_gateway_id          = optional(string)
    local_gateway_id            = optional(string)
  }))
  default  = {}
  nullable = false

  validation {
    condition     = alltrue([for key in keys(var.routes) : can(regex("^[a-z0-9][a-z0-9-]{0,62}$", key))])
    error_message = "Route keys must be 1-63 lowercase alphanumeric characters or hyphens."
  }

  validation {
    condition = alltrue([for route in values(var.routes) :
      length([for destination in [route.destination_cidr_block, route.destination_ipv6_cidr_block, route.destination_prefix_list_id] : destination if destination != null]) == 1
    ])
    error_message = "Each route must name exactly one destination: destination_cidr_block, destination_ipv6_cidr_block, or destination_prefix_list_id."
  }

  validation {
    condition = alltrue([for route in values(var.routes) :
      length([for target in [route.transit_gateway_id, route.nat_gateway_id, route.gateway_id, route.egress_only_gateway_id, route.vpc_peering_connection_id, route.network_interface_id, route.vpc_endpoint_id, route.core_network_arn, route.carrier_gateway_id, route.local_gateway_id] : target if target != null]) == 1
    ])
    error_message = "Each route must name exactly one target."
  }

  validation {
    condition = alltrue([for route in values(var.routes) :
      route.destination_cidr_block == null ? true : can(cidrhost(route.destination_cidr_block, 0))
    ])
    error_message = "destination_cidr_block must be a valid IPv4 CIDR."
  }

  validation {
    condition     = alltrue([for route in values(var.routes) : !(route.vpc_endpoint_id != null && route.destination_prefix_list_id != null)])
    error_message = "A route to a VPC endpoint (Gateway Load Balancer) needs a CIDR destination; AWS does not accept prefix-list destinations for endpoint targets."
  }
}

variable "allow_default_route" {
  description = "Permit 0.0.0.0/0 and ::/0 destinations. Off by default so a private tier cannot be given an internet path by accident."
  type        = bool
  default     = false
  nullable    = false
}
