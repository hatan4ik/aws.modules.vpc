variable "region" {
  description = "AWS region the VPC is created in."
  type        = string
  default     = "us-east-2"
}

variable "name" {
  description = "VPC name; also the prefix of every subnet, route table, gateway, and flow-log resource name."
  type        = string
  default     = "web-network"
}

variable "cidr_block" {
  description = "Primary IPv4 CIDR of the VPC. The tier layout (public /24s, private /20s, data /22s for a /16) is relative to it, so use a /16 to /20 block."
  type        = string

  validation {
    condition     = can(cidrhost(var.cidr_block, 0)) && tonumber(split("/", var.cidr_block)[1]) <= 20
    error_message = "cidr_block must be a valid IPv4 CIDR of /20 or larger so every tier gets usable subnets."
  }
}

variable "availability_zones" {
  description = "Availability Zone of each subnet, keyed by the stable AZ keys (az1, az2) that name the subnets, route tables, and NAT gateway. All three tiers use the same zones."
  type = object({
    az1 = string
    az2 = string
  })
}

variable "tags" {
  description = "Tags applied to every resource."
  type        = map(string)
  default     = {}
}
