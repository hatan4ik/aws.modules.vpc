variable "vpc_id" {
  description = "VPC the tier belongs to."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^vpc-[0-9a-f]+$", var.vpc_id))
    error_message = "vpc_id must be a VPC ID (vpc-...)."
  }
}

variable "vpc_cidr_block" {
  description = "Primary IPv4 CIDR of the VPC. Required when any subnet is allocated with newbits and netnum instead of an explicit cidr_block."
  type        = string
  default     = null

  validation {
    condition     = var.vpc_cidr_block == null ? true : can(cidrhost(var.vpc_cidr_block, 0))
    error_message = "vpc_cidr_block must be a valid IPv4 CIDR."
  }
}

variable "name" {
  description = "VPC name; subnet and route-table names are <name>-<tier>-<az_key>."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,50}$", var.name))
    error_message = "name must be lowercase, hyphenated, and 3-51 characters."
  }
}

variable "tier" {
  description = "Tier identifier, also the Tier tag value the platform uses to discover subnets and route tables (for example private, transit, public)."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,30}$", var.tier))
    error_message = "tier must be 1-31 lowercase alphanumeric characters or hyphens, starting with a letter."
  }
}

variable "availability_zones" {
  description = "Subnets of the tier keyed by a stable AZ key. Each declares either an explicit cidr_block or newbits and netnum relative to vpc_cidr_block."
  type = map(object({
    availability_zone = string
    cidr_block        = optional(string)
    newbits           = optional(number)
    netnum            = optional(number)
  }))
  nullable = false

  validation {
    condition     = length(var.availability_zones) >= 1
    error_message = "availability_zones must declare at least one subnet."
  }

  validation {
    condition     = alltrue([for key in keys(var.availability_zones) : can(regex("^[a-z0-9][a-z0-9-]{0,15}$", key))])
    error_message = "availability_zones keys must be 1-16 lowercase alphanumeric characters or hyphens."
  }

  validation {
    condition = alltrue([for zone in values(var.availability_zones) :
      (zone.cidr_block != null) != (zone.newbits != null && zone.netnum != null)
    ])
    error_message = "Each subnet must declare exactly one of cidr_block, or both newbits and netnum."
  }

  validation {
    condition = alltrue([for zone in values(var.availability_zones) :
      zone.cidr_block == null ? true : can(cidrhost(zone.cidr_block, 0))
    ])
    error_message = "Every cidr_block must be a valid IPv4 CIDR."
  }

  validation {
    condition = alltrue([for zone in values(var.availability_zones) :
      zone.newbits == null ? true : (zone.newbits >= 1 && zone.newbits <= 16 && zone.netnum >= 0 && floor(zone.netnum) == zone.netnum)
    ])
    error_message = "newbits must be 1-16 and netnum a non-negative whole number."
  }

  validation {
    condition     = length(distinct([for zone in values(var.availability_zones) : zone.availability_zone])) == length(var.availability_zones)
    error_message = "Each subnet of a tier must be in a distinct Availability Zone."
  }
}

variable "route_tables" {
  description = "per_az creates one route table per subnet (the resilient default); shared creates one route table for the tier."
  type        = string
  default     = "per_az"
  nullable    = false

  validation {
    condition     = contains(["per_az", "shared"], var.route_tables)
    error_message = "route_tables must be per_az or shared."
  }
}

variable "map_public_ip_on_launch" {
  description = "Assign public IPv4 addresses to instances launched in the tier. Only meaningful for a public tier."
  type        = bool
  default     = false
  nullable    = false
}

variable "private_dns_hostname_type_on_launch" {
  description = "Hostname type for instances launched in the tier: ip-name or resource-name."
  type        = string
  default     = null

  validation {
    condition     = var.private_dns_hostname_type_on_launch == null ? true : contains(["ip-name", "resource-name"], var.private_dns_hostname_type_on_launch)
    error_message = "private_dns_hostname_type_on_launch must be ip-name or resource-name."
  }
}

variable "tags" {
  description = "Tags applied to every subnet and route table; Name and Tier are added by the module."
  type        = map(string)
  default     = {}
  nullable    = false
}
