variable "delegated_admin_account_id" {
  description = "Network-account ID delegated by the AWS Organizations management account to administer VPC IPAM."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[0-9]{12}$", var.delegated_admin_account_id))
    error_message = "delegated_admin_account_id must be a 12-digit AWS account ID."
  }
}

variable "tags" {
  description = "Allocation and ownership tags for the Organization-level IPAM delegation record."
  type        = map(string)
  default     = {}
  nullable    = false
}
