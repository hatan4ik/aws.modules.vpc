variable "vpc_id" {
  description = "VPC the endpoints belong to."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^vpc-[0-9a-f]+$", var.vpc_id))
    error_message = "vpc_id must be a VPC ID (vpc-...)."
  }
}

variable "name" {
  description = "VPC name; endpoints are named <name>-<key> and the endpoint security group <name>-interface-endpoints."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,50}$", var.name))
    error_message = "name must be lowercase, hyphenated, and 3-51 characters."
  }
}

variable "vpc_cidr_blocks" {
  description = "CIDR blocks allowed to reach interface endpoints over HTTPS through the created security group (normally the VPC CIDRs). A list, so an IPAM-allocated CIDR that is unknown until apply is accepted."
  type        = list(string)
  default     = []
  nullable    = false
}

variable "create_security_group" {
  description = "Create the interface-endpoint security group (HTTPS from vpc_cidr_blocks, no egress)."
  type        = bool
  default     = true
  nullable    = false
}

variable "security_group_name" {
  description = "Name of the created security group. Defaults to <name>-interface-endpoints."
  type        = string
  default     = null
}

variable "security_group_description" {
  description = "Description of the created security group. Changing it replaces the group."
  type        = string
  default     = "Permits private HTTPS connections from this VPC to its AWS interface endpoints."
  nullable    = false
}

variable "security_group_ids" {
  description = "Additional security groups attached to every interface endpoint, or the only groups when create_security_group is false."
  type        = set(string)
  default     = []
  nullable    = false
}

variable "interface_endpoints" {
  description = "Interface (PrivateLink) endpoints keyed by a stable identifier. service_name is the full AWS service name so the module never infers a Region."
  type = map(object({
    service_name                                   = string
    subnet_ids                                     = set(string)
    private_dns_enabled                            = optional(bool, true)
    policy_json                                    = optional(string)
    ip_address_type                                = optional(string)
    dns_record_ip_type                             = optional(string)
    private_dns_only_for_inbound_resolver_endpoint = optional(bool)
  }))
  default  = {}
  nullable = false

  validation {
    condition     = alltrue([for key in keys(var.interface_endpoints) : can(regex("^[a-z0-9][a-z0-9-]{0,62}$", key))])
    error_message = "interface_endpoints keys must be 1-63 lowercase alphanumeric characters or hyphens."
  }

  validation {
    condition     = alltrue([for endpoint in values(var.interface_endpoints) : can(regex("^(com\\.amazonaws(?:\\.[a-z0-9-]+)?\\.[a-z0-9.-]+|aws\\.[a-z0-9.-]+)$", endpoint.service_name)) && length(endpoint.subnet_ids) > 0])
    error_message = "Each interface endpoint needs an AWS service name (com.amazonaws.<region>.<service> or aws.<service>) and at least one subnet."
  }

  validation {
    condition     = alltrue([for endpoint in values(var.interface_endpoints) : endpoint.ip_address_type == null ? true : contains(["ipv4", "ipv6", "dualstack"], endpoint.ip_address_type)])
    error_message = "ip_address_type must be ipv4, ipv6, or dualstack."
  }
}

variable "gateway_endpoints" {
  description = "Gateway endpoints (S3, DynamoDB) keyed by a stable identifier, associated with the given route tables."
  type = map(object({
    service_name    = string
    route_table_ids = set(string)
    policy_json     = optional(string)
  }))
  default  = {}
  nullable = false

  validation {
    condition     = alltrue([for key in keys(var.gateway_endpoints) : can(regex("^[a-z0-9][a-z0-9-]{0,62}$", key))])
    error_message = "gateway_endpoints keys must be 1-63 lowercase alphanumeric characters or hyphens."
  }

  validation {
    condition     = alltrue([for endpoint in values(var.gateway_endpoints) : can(regex("^com\\.amazonaws(?:\\.[a-z0-9-]+)?\\.[a-z0-9.-]+$", endpoint.service_name)) && length(endpoint.route_table_ids) > 0])
    error_message = "Each gateway endpoint needs an AWS service name and at least one route table."
  }
}

variable "tags" {
  description = "Tags applied to every endpoint and the security group; Name is added by the module."
  type        = map(string)
  default     = {}
  nullable    = false
}
