# ---------------------------------------------------------------------------
# Identity and addressing
# ---------------------------------------------------------------------------

variable "name" {
  description = "VPC name. Tagged as Name on the VPC and used as the prefix of every subnet, route table, gateway, endpoint, and flow-log name."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,50}$", var.name))
    error_message = "name must be lowercase, hyphenated, and 3-51 characters."
  }
}

variable "cidr_block" {
  description = "Primary IPv4 CIDR of the VPC. Mutually exclusive with ipam."
  type        = string
  default     = null

  validation {
    condition     = var.cidr_block == null ? true : can(cidrhost(var.cidr_block, 0))
    error_message = "cidr_block must be a valid IPv4 CIDR."
  }
}

variable "ipam" {
  description = "Allocate the primary CIDR from an AWS VPC IPAM pool instead of cidr_block. Subnets then derive their CIDRs with newbits and netnum."
  type = object({
    pool_id        = string
    netmask_length = number
  })
  default = null

  validation {
    condition     = var.ipam == null ? true : (can(regex("^ipam-pool-[0-9a-f]+$", var.ipam.pool_id)) && var.ipam.netmask_length >= 16 && var.ipam.netmask_length <= 28)
    error_message = "ipam.pool_id must be an IPAM pool ID and ipam.netmask_length between 16 and 28."
  }
}

variable "secondary_cidr_blocks" {
  description = "Additional IPv4 CIDR blocks associated with the VPC."
  type        = set(string)
  default     = []
  nullable    = false

  validation {
    condition     = alltrue([for cidr in var.secondary_cidr_blocks : can(cidrhost(cidr, 0))])
    error_message = "Every secondary CIDR must be a valid IPv4 CIDR."
  }
}

variable "instance_tenancy" {
  description = "Tenancy of instances launched in the VPC: default or dedicated."
  type        = string
  default     = "default"
  nullable    = false

  validation {
    condition     = contains(["default", "dedicated"], var.instance_tenancy)
    error_message = "instance_tenancy must be default or dedicated."
  }
}

variable "enable_dns_support" {
  description = "Enable DNS resolution through the Amazon-provided resolver."
  type        = bool
  default     = true
  nullable    = false
}

variable "enable_dns_hostnames" {
  description = "Assign DNS hostnames to instances."
  type        = bool
  default     = true
  nullable    = false
}

variable "enable_network_address_usage_metrics" {
  description = "Publish Network Address Usage metrics for the VPC."
  type        = bool
  default     = true
  nullable    = false
}

variable "vpc_encryption_control" {
  description = "VPC Encryption Control mode: enforce (default), monitor, or null to leave it unmanaged."
  type        = string
  default     = "enforce"

  validation {
    condition     = var.vpc_encryption_control == null ? true : contains(["enforce", "monitor"], var.vpc_encryption_control)
    error_message = "vpc_encryption_control must be enforce, monitor, or null."
  }
}

# ---------------------------------------------------------------------------
# Subnet tiers and routes
# ---------------------------------------------------------------------------

variable "subnets" {
  description = "Subnet tiers keyed by tier name (the Tier tag), for example private, transit, public. Each tier lists its subnets by AZ key with an explicit cidr_block or newbits and netnum, chooses per_az or shared route tables, and declares routes whose targets are IDs or references to gateways this module creates (nat_gateway_key, internet_gateway, egress_only_internet_gateway)."
  type = map(object({
    availability_zones = map(object({
      availability_zone = string
      cidr_block        = optional(string)
      newbits           = optional(number)
      netnum            = optional(number)
    }))
    route_tables                        = optional(string, "per_az")
    map_public_ip_on_launch             = optional(bool, false)
    private_dns_hostname_type_on_launch = optional(string)
    allow_default_route                 = optional(bool, false)
    routes = optional(map(object({
      destination_cidr_block       = optional(string)
      destination_ipv6_cidr_block  = optional(string)
      destination_prefix_list_id   = optional(string)
      transit_gateway_id           = optional(string)
      nat_gateway_id               = optional(string)
      nat_gateway_key              = optional(string)
      gateway_id                   = optional(string)
      internet_gateway             = optional(bool, false)
      egress_only_gateway_id       = optional(string)
      egress_only_internet_gateway = optional(bool, false)
      vpc_peering_connection_id    = optional(string)
      network_interface_id         = optional(string)
      vpc_endpoint_id              = optional(string)
      core_network_arn             = optional(string)
      carrier_gateway_id           = optional(string)
      local_gateway_id             = optional(string)
    })), {})
  }))
  nullable = false

  validation {
    condition     = length(var.subnets) > 0
    error_message = "subnets must declare at least one tier."
  }

  validation {
    condition     = alltrue([for tier in keys(var.subnets) : can(regex("^[a-z][a-z0-9-]{0,30}$", tier))])
    error_message = "Tier keys must be 1-31 lowercase alphanumeric characters or hyphens, starting with a letter."
  }

  validation {
    condition = alltrue(flatten([for tier in values(var.subnets) : [for route in values(tier.routes) :
      length([for target in [route.transit_gateway_id, route.nat_gateway_id, route.nat_gateway_key, route.gateway_id, route.egress_only_gateway_id, route.vpc_peering_connection_id, route.network_interface_id, route.vpc_endpoint_id, route.core_network_arn, route.carrier_gateway_id, route.local_gateway_id] : target if target != null]) + (route.internet_gateway ? 1 : 0) + (route.egress_only_internet_gateway ? 1 : 0) == 1
    ]]))
    error_message = "Each route must name exactly one target: an ID, nat_gateway_key, internet_gateway = true, or egress_only_internet_gateway = true."
  }
}

# ---------------------------------------------------------------------------
# Internet access (off unless declared)
# ---------------------------------------------------------------------------

variable "internet" {
  description = "Internet gateway, optional egress-only gateway, and NAT gateways. Null (the default) creates no internet path. nat_gateways are keyed by a short name and placed in a subnet given as <tier>/<az_key>."
  type = object({
    create_internet_gateway             = optional(bool, true)
    create_egress_only_internet_gateway = optional(bool, false)
    nat_gateways = optional(map(object({
      subnet            = string
      allocation_id     = optional(string)
      connectivity_type = optional(string, "public")
      private_ip        = optional(string)
    })), {})
  })
  default = null

  validation {
    condition     = var.internet == null ? true : alltrue([for gateway in values(var.internet.nat_gateways) : can(regex("^[a-z][a-z0-9-]*/[a-z0-9][a-z0-9-]*$", gateway.subnet))])
    error_message = "Each nat_gateways entry must name its subnet as <tier>/<az_key>."
  }
}

# ---------------------------------------------------------------------------
# Endpoints (none unless declared)
# ---------------------------------------------------------------------------

variable "endpoints" {
  description = "VPC endpoints. Interface endpoints are placed in the subnets of subnet_tier; gateway endpoints are associated with the route tables of route_table_tiers. A locked-down HTTPS security group is created unless security_group_ids are supplied."
  type = object({
    create_security_group      = optional(bool, true)
    security_group_name        = optional(string)
    security_group_description = optional(string)
    security_group_ids         = optional(set(string), [])
    interface = optional(map(object({
      service_name                                   = string
      subnet_tier                                    = string
      private_dns_enabled                            = optional(bool, true)
      policy_json                                    = optional(string)
      ip_address_type                                = optional(string)
      dns_record_ip_type                             = optional(string)
      private_dns_only_for_inbound_resolver_endpoint = optional(bool)
    })), {})
    gateway = optional(map(object({
      service_name      = string
      route_table_tiers = set(string)
      policy_json       = optional(string)
    })), {})
  })
  default = null
}

# ---------------------------------------------------------------------------
# Flow logs (on by default)
# ---------------------------------------------------------------------------

variable "flow_logs" {
  description = "VPC Flow Logs. The default delivers all traffic to a CloudWatch log group with one-year retention; set destination.kms_key_arn or destination.create_kms_key for a customer-managed key, destination.type = s3 for an S3 bucket, or null to disable."
  type = object({
    destination = optional(object({
      type             = optional(string, "cloud-watch-logs")
      log_group_name   = optional(string)
      create_log_group = optional(bool, true)
      log_group_arn    = optional(string)
      log_group_class  = optional(string, "STANDARD")
      kms_key_arn      = optional(string)
      create_kms_key   = optional(bool, false)
      s3_bucket_arn    = optional(string)
      s3_options = optional(object({
        file_format                = optional(string, "plain-text")
        hive_compatible_partitions = optional(bool, false)
        per_hour_partition         = optional(bool, false)
      }))
    }), {})
    retention_in_days               = optional(number, 365)
    traffic_type                    = optional(string, "ALL")
    max_aggregation_interval        = optional(number, 60)
    log_format                      = optional(string)
    role_name                       = optional(string)
    role_path                       = optional(string, "/")
    role_permissions_boundary       = optional(string)
    kms_key_deletion_window_in_days = optional(number, 30)
    partition                       = optional(string)
    region                          = optional(string)
    account_id                      = optional(string)
  })
  default = {}
}

variable "tags" {
  description = "Tags applied to every resource. The module adds Name (and Tier on subnets and route tables) and never overrides caller tags."
  type        = map(string)
  default     = {}
  nullable    = false
}
