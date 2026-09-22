variable "name" {
  description = "Stable name for the isolated sandbox network."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,50}$", var.name))
    error_message = "name must be lowercase, hyphenated, and 3-51 characters."
  }
}

variable "vpc_cidr" {
  description = "IPv4 CIDR explicitly allocated to this sandbox VPC."
  type        = string
  nullable    = false

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr must be a valid IPv4 CIDR."
  }
}

variable "availability_zones" {
  description = "Stable subnet key to available AWS Availability Zone name mapping."
  type        = map(string)
  nullable    = false

  validation {
    condition     = length(var.availability_zones) >= 2
    error_message = "At least two Availability Zones are required."
  }
}

variable "private_subnet_cidrs" {
  description = "Stable subnet key to private IPv4 CIDR mapping. Keys must match availability_zones, enforced by the VPC precondition."
  type        = map(string)
  nullable    = false

  validation {
    condition     = alltrue([for cidr in values(var.private_subnet_cidrs) : can(cidrhost(cidr, 0))])
    error_message = "Every private_subnet_cidrs value must be a valid IPv4 CIDR."
  }
}

variable "flow_log_retention_in_days" {
  description = "CloudWatch Logs retention period for VPC flow logs; security baseline requires at least one year."
  type        = number
  default     = 365
  nullable    = false

  validation {
    condition     = var.flow_log_retention_in_days >= 365 && contains([365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653], var.flow_log_retention_in_days)
    error_message = "flow_log_retention_in_days must be a supported CloudWatch Logs retention period of at least 365 days."
  }
}

variable "tags" {
  description = "Allocation, ownership, and traceability tags applied to all taggable resources."
  type        = map(string)
  default     = {}
  nullable    = false
}
