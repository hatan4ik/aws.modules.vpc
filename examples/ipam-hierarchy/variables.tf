variable "region" {
  description = "IPAM home Region. The delegation, the IPAM, and every RAM share are administered here, and operating_regions must include it."
  type        = string
  default     = "us-east-2"
}

variable "management_role_arn" {
  description = "ARN of a role in the AWS Organizations management account that the aliased provider assumes to delegate IPAM administration and enable RAM organization sharing."
  type        = string
}

variable "network_account_id" {
  description = "12-digit ID of the Network account that becomes the delegated VPC IPAM administrator and owns the IPAM. The default provider's credentials must belong to it."
  type        = string
}

variable "name" {
  description = "IPAM name; also the prefix of the pool and RAM-share names."
  type        = string
  default     = "enterprise"
}

variable "operating_regions" {
  description = "Every Region in which the IPAM manages private address space, including region."
  type        = set(string)
}

variable "top_level_cidr" {
  description = "Enterprise-approved IPv4 range reserved for the non-allocating top-level pool, for example 10.0.0.0/8."
  type        = string
}

variable "regional_pools" {
  description = "Allocatable Regional child pools keyed by a short name. Each names its locale (an operating Region), the CIDR it takes from top_level_cidr, the default VPC allocation size, optional min/max sizes, tags every allocation must carry, and the account IDs or Organizations principal ARNs it is RAM-shared with."
  type = map(object({
    locale                            = string
    cidr                              = string
    allocation_default_netmask_length = number
    allocation_min_netmask_length     = optional(number)
    allocation_max_netmask_length     = optional(number)
    allocation_resource_tags          = optional(map(string), {})
    ram_principals                    = optional(set(string), [])
  }))
}

variable "tags" {
  description = "Tags applied to the IPAM, the pools, and the RAM shares."
  type        = map(string)
  default     = {}
}
