variable "region" {
  description = "AWS region the VPC is created in; the log group must be in the same region."
  type        = string
  default     = "us-east-2"
}

variable "name" {
  description = "VPC name; also the prefix of every subnet, route table, and flow-log resource name."
  type        = string
  default     = "orders-network"
}

variable "cidr_block" {
  description = "Primary IPv4 CIDR of the VPC, for example 10.64.0.0/16."
  type        = string
}

variable "secondary_cidr_blocks" {
  description = "Additional IPv4 CIDR blocks associated with the VPC. They must not overlap cidr_block or each other."
  type        = set(string)
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

variable "flow_log_group_arn" {
  description = "ARN of the existing CloudWatch log group that receives the flow logs. The delivery role is scoped to this group."
  type        = string

  validation {
    condition     = can(regex("^arn:[^:]+:logs:[^:]+:[0-9]{12}:log-group:", var.flow_log_group_arn))
    error_message = "flow_log_group_arn must be a CloudWatch Logs log group ARN."
  }
}

variable "flow_log_group_name" {
  description = "Name of that log group, reported through the flow_log_group_name output for consumers that address the group by name."
  type        = string
}

variable "flow_log_kms_key_arn" {
  description = "ARN of the KMS key the log group is encrypted with, reported through the flow_log_kms_key_arn output. The module does not change the group's encryption."
  type        = string
}

variable "tags" {
  description = "Tags applied to every resource."
  type        = map(string)
  default     = {}
}
