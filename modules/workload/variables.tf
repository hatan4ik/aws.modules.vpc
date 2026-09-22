variable "name" {
  description = "Lowercase workload VPC name used in resource names and tags."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,62}$", var.name))
    error_message = "name must be 3-63 lowercase letters, digits, and hyphens and start with a letter."
  }
}

variable "ipv4_ipam_pool_id" {
  description = "Approved AWS VPC IPAM pool from which AWS allocates the VPC CIDR."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^ipam-pool-[0-9a-f]+$", var.ipv4_ipam_pool_id))
    error_message = "ipv4_ipam_pool_id must be an AWS IPAM pool ID."
  }
}

variable "ipv4_netmask_length" {
  description = "IPv4 prefix length AWS VPC IPAM allocates to this VPC."
  type        = number
  nullable    = false

  validation {
    condition     = var.ipv4_netmask_length >= 16 && var.ipv4_netmask_length <= 28
    error_message = "ipv4_netmask_length must be between /16 and /28."
  }
}

variable "availability_zones" {
  description = "Stable AZ-keyed private-subnet allocation plan. Each netnum is evaluated against the VPC CIDR allocated by IPAM."
  type = map(object({
    availability_zone = string
    subnet_newbits    = number
    subnet_netnum     = number
  }))
  nullable = false

  validation {
    condition     = length(var.availability_zones) >= 2
    error_message = "availability_zones must define at least two Availability Zones."
  }

  validation {
    condition = alltrue([
      for zone in values(var.availability_zones) :
      zone.subnet_newbits >= 1 && zone.subnet_newbits <= 16 && zone.subnet_netnum >= 0 && floor(zone.subnet_netnum) == zone.subnet_netnum
    ])
    error_message = "Each subnet allocation needs subnet_newbits from 1 through 16 and a non-negative whole-number subnet_netnum."
  }

  validation {
    condition     = length(distinct([for zone in values(var.availability_zones) : zone.availability_zone])) == length(var.availability_zones)
    error_message = "Each availability_zone value must be unique."
  }
}

variable "interface_endpoints" {
  description = "Stable endpoint-keyed AWS PrivateLink services. Service names are passed explicitly so the module does not infer a Region."
  type = map(object({
    service_name        = string
    private_dns_enabled = bool
    policy_json         = optional(string)
  }))
  default  = {}
  nullable = false

  validation {
    condition     = alltrue([for endpoint in values(var.interface_endpoints) : can(regex("^com\\.amazonaws(?:\\.[a-z0-9-]+)?\\.[a-z0-9-]+$", endpoint.service_name))])
    error_message = "Each interface endpoint service_name must be an AWS PrivateLink service name."
  }
}

variable "gateway_endpoints" {
  description = "Stable endpoint-keyed gateway endpoint services and optional restrictive endpoint policies."
  type = map(object({
    service_name = string
    policy_json  = optional(string)
  }))
  default  = {}
  nullable = false

  validation {
    condition     = alltrue([for endpoint in values(var.gateway_endpoints) : can(regex("^com\\.amazonaws(?:\\.[a-z0-9-]+)?\\.[a-z0-9-]+$", endpoint.service_name))])
    error_message = "Each gateway endpoint service_name must be an AWS endpoint service name."
  }
}

variable "flow_log_kms_key_arn" {
  description = "Customer-managed KMS key ARN used to encrypt the VPC Flow Logs CloudWatch log group."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^arn:[^:]+:kms:[^:]+:[0-9]{12}:key/.+$", var.flow_log_kms_key_arn))
    error_message = "flow_log_kms_key_arn must be a customer-managed KMS key ARN."
  }
}

variable "flow_log_retention_in_days" {
  description = "Approved CloudWatch retention period for VPC Flow Logs."
  type        = number
  nullable    = false

  validation {
    condition     = var.flow_log_retention_in_days > 0 && floor(var.flow_log_retention_in_days) == var.flow_log_retention_in_days
    error_message = "flow_log_retention_in_days must be a positive whole number."
  }
}

variable "tags" {
  description = "Additional required allocation and ownership tags. Name and Component tags are computed by the module."
  type        = map(string)
  default     = {}
  nullable    = false

  validation {
    condition = alltrue([
      for k in keys(var.tags) : can(regex("^[A-Z][A-Za-z0-9]+$", k))
    ])
    error_message = "Tag keys must be PascalCase (e.g. Application, CostCenter, Owner)."
  }

  validation {
    condition     = alltrue([for v in values(var.tags) : length(trimspace(v)) > 0])
    error_message = "Tag values must be non-empty strings."
  }
}
