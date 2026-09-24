variable "vpc_id" {
  description = "VPC that receives the gateways."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^vpc-[0-9a-f]+$", var.vpc_id))
    error_message = "vpc_id must be a VPC ID (vpc-...)."
  }
}

variable "name" {
  description = "VPC name; the internet gateway is <name>-igw and NAT gateways <name>-nat-<key>."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,50}$", var.name))
    error_message = "name must be lowercase, hyphenated, and 3-51 characters."
  }
}

variable "create_internet_gateway" {
  description = "Create an internet gateway. Required for public NAT gateways and public subnets."
  type        = bool
  default     = true
  nullable    = false
}

variable "create_egress_only_internet_gateway" {
  description = "Create an egress-only internet gateway for IPv6-only outbound traffic."
  type        = bool
  default     = false
  nullable    = false
}

variable "nat_gateways" {
  description = "NAT gateways keyed by a stable identifier (normally the AZ key). Each sits in a subnet; a public NAT gateway gets a created Elastic IP unless allocation_id is supplied; a private NAT gateway needs neither."
  type = map(object({
    subnet_id         = string
    allocation_id     = optional(string)
    connectivity_type = optional(string, "public")
    private_ip        = optional(string)
  }))
  default  = {}
  nullable = false

  validation {
    condition     = alltrue([for key in keys(var.nat_gateways) : can(regex("^[a-zA-Z0-9][a-zA-Z0-9_-]{0,31}$", key))])
    error_message = "nat_gateways keys must be 1-32 characters of letters, digits, underscores, or hyphens."
  }

  validation {
    condition = alltrue([for gateway in values(var.nat_gateways) :
      can(regex("^subnet-[0-9a-f]+$", gateway.subnet_id)) && contains(["public", "private"], gateway.connectivity_type) &&
      (gateway.connectivity_type == "private" ? gateway.allocation_id == null : true)
    ])
    error_message = "Each NAT gateway needs a subnet ID, connectivity_type public or private, and no allocation_id when private."
  }
}

variable "tags" {
  description = "Tags applied to every gateway and Elastic IP; Name is added by the module."
  type        = map(string)
  default     = {}
  nullable    = false
}
