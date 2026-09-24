variable "region" {
  description = "AWS region the VPC is created in; also the region segment of every endpoint service name."
  type        = string
  default     = "us-east-2"
}

variable "name" {
  description = "VPC name; also the prefix of every subnet, route table, endpoint, and flow-log resource name."
  type        = string
  default     = "orders-network"
}

variable "ipam_pool_id" {
  description = "IPAM pool (ipam-pool-...) the primary CIDR is allocated from. The pool must be localized to region and shared with this account."
  type        = string
}

variable "ipam_netmask_length" {
  description = "Prefix length of the allocated CIDR. The subnet layout carves quarters and 1/64 slices from it, so it must be /22 or larger."
  type        = number

  validation {
    condition     = var.ipam_netmask_length >= 16 && var.ipam_netmask_length <= 22
    error_message = "ipam_netmask_length must be between 16 and 22 so the transit subnets (newbits = 6) stay at /28 or larger."
  }
}

variable "availability_zones" {
  description = "Availability Zone of each subnet, keyed by the stable AZ keys (az1, az2) that name the subnets and route tables. Both tiers use the same zones."
  type = object({
    az1 = string
    az2 = string
  })
}

variable "transit_gateway_id" {
  description = "Transit Gateway (tgw-...) the private tier routes hub traffic to. Its attachment to the transit subnets is created outside this example."
  type        = string
}

variable "hub_cidr_block" {
  description = "IPv4 CIDR reached through the Transit Gateway, for example the enterprise 10.0.0.0/8. A default route is rejected because the tier does not set allow_default_route."
  type        = string

  validation {
    condition     = can(cidrhost(var.hub_cidr_block, 0))
    error_message = "hub_cidr_block must be a valid IPv4 CIDR."
  }
}

variable "flow_log_kms_key_arn" {
  description = "ARN of an existing KMS key that encrypts the flow-log log group. Its policy must let logs.<region>.amazonaws.com use it for the group."
  type        = string
}

variable "tags" {
  description = "Tags applied to every resource."
  type        = map(string)
  default     = {}
}
