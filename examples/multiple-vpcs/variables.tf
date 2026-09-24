variable "region" {
  description = "AWS region every VPC is created in."
  type        = string
  default     = "us-east-2"
}

variable "name_prefix" {
  description = "Prefix of every VPC name; the map key is appended (<prefix>-<key>)."
  type        = string
  default     = "platform"
}

variable "vpcs" {
  description = "VPCs keyed by a short name that becomes the suffix of the VPC name and its Network tag. Each declares its primary CIDR and its subnet tiers; every subnet names an Availability Zone and either an explicit cidr_block or newbits and netnum relative to the VPC CIDR. CIDRs must not overlap across VPCs that will be connected."
  type = map(object({
    cidr_block = string
    subnets = map(object({
      availability_zones = map(object({
        availability_zone = string
        cidr_block        = optional(string)
        newbits           = optional(number)
        netnum            = optional(number)
      }))
      route_tables = optional(string, "per_az")
    }))
  }))
}

variable "tags" {
  description = "Tags applied to every resource of every VPC."
  type        = map(string)
  default     = {}
}
