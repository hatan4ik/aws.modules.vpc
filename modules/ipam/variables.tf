variable "name" {
  description = "Lowercase IPAM name used for the IPAM, pool, and RAM-share names."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,62}$", var.name))
    error_message = "name must be 3-63 lowercase letters, digits, and hyphens and start with a letter."
  }
}

variable "home_region" {
  description = "AWS Region in which the IPAM and its RAM shares are administered. The caller must run this module with a provider for this Region."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z]{2}(-gov)?-[a-z]+-[0-9]+$", var.home_region))
    error_message = "home_region must be a valid AWS Region identifier."
  }
}

variable "operating_regions" {
  description = "All Regions in which this IPAM manages private address space, including home_region."
  type        = set(string)
  nullable    = false

  validation {
    condition     = length(var.operating_regions) >= 1 && alltrue([for region in var.operating_regions : can(regex("^[a-z]{2}(-gov)?-[a-z]+-[0-9]+$", region))])
    error_message = "operating_regions must contain one or more valid AWS Region identifiers."
  }
}

variable "top_level_cidr" {
  description = "Enterprise-approved IPv4 CIDR reserved for this IPAM's top-level private pool. It must be approved as non-overlapping before any apply."
  type        = string
  nullable    = false

  validation {
    condition     = can(cidrhost(var.top_level_cidr, 0)) && !strcontains(var.top_level_cidr, ":")
    error_message = "top_level_cidr must be a valid IPv4 CIDR."
  }
}

variable "regional_pools" {
  description = "Regional private pools allocated from top_level_cidr. Each may be RAM-shared only with approved accounts or Organizations principals."
  type = map(object({
    locale                            = string
    cidr                              = string
    allocation_default_netmask_length = number
    allocation_min_netmask_length     = optional(number)
    allocation_max_netmask_length     = optional(number)
    allocation_resource_tags          = optional(map(string), {})
    ram_principals                    = optional(set(string), [])
  }))
  nullable = false

  validation {
    condition     = length(var.regional_pools) > 0 && length(distinct([for pool in values(var.regional_pools) : pool.locale])) == length(var.regional_pools)
    error_message = "regional_pools must contain at least one pool and exactly one pool for each locale."
  }

  validation {
    condition = alltrue([
      for pool in values(var.regional_pools) :
      can(regex("^[a-z]{2}(-gov)?-[a-z]+-[0-9]+$", pool.locale)) &&
      can(cidrhost(pool.cidr, 0)) &&
      !strcontains(pool.cidr, ":") &&
      pool.allocation_default_netmask_length >= 16 &&
      pool.allocation_default_netmask_length <= 28 &&
      try(pool.allocation_min_netmask_length <= pool.allocation_default_netmask_length, true) &&
      try(pool.allocation_max_netmask_length >= pool.allocation_default_netmask_length, true)
    ])
    error_message = "Each regional pool needs a valid IPv4 CIDR and compatible VPC allocation netmask lengths from /16 through /28."
  }

  validation {
    condition = alltrue(flatten([
      for pool in values(var.regional_pools) : [
        for principal in pool.ram_principals :
        can(regex("^[0-9]{12}$", principal)) ||
        can(regex("^arn:[^:]+:organizations::[0-9]{12}:organization/o-[a-z0-9-]+$", principal)) ||
        can(regex("^arn:[^:]+:organizations::[0-9]{12}:ou/o-[a-z0-9-]+/ou-[a-z0-9-]+$", principal))
      ]
    ]))
    error_message = "regional_pools.ram_principals may contain only 12-digit account IDs or AWS Organizations organization/OU ARNs; IAM principals are not accepted by this platform contract."
  }
}

variable "tags" {
  description = "Additional allocation and ownership tags. Name and Component tags are computed by the module."
  type        = map(string)
  default     = {}
  nullable    = false
}
