variable "region" {
  description = "AWS region the VPC is created in."
  type        = string
  default     = "us-east-2"
}

variable "name" {
  description = "VPC name; also the prefix of every subnet, route table, and flow-log resource name."
  type        = string
  default     = "sandbox-network"
}

variable "cidr_block" {
  description = "Primary IPv4 CIDR of the VPC, for example 10.64.0.0/16."
  type        = string
}

variable "availability_zones" {
  description = "Availability Zone of each private subnet, keyed by the stable AZ keys (az1, az2) that name the subnets and route tables."
  type = object({
    az1 = string
    az2 = string
  })
}

variable "private_subnet_cidrs" {
  description = "IPv4 CIDR of each private subnet, keyed like availability_zones. Both must lie inside cidr_block."
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
