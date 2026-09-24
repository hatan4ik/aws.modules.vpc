variable "delegated_admin_account_id" {
  description = "Network-account ID delegated by the AWS Organizations management account to administer VPC IPAM."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[0-9]{12}$", var.delegated_admin_account_id))
    error_message = "delegated_admin_account_id must be a 12-digit AWS account ID."
  }
}

# Neither the RAM organization-sharing flag nor the IPAM delegation record
# supports tags, so the value has no effect. The input is kept so callers can
# pass their default tags to every submodule uniformly.
# tflint-ignore: terraform_unused_declarations
variable "tags" {
  description = "Accepted for interface uniformity with the other submodules; neither resource of this module supports tags, so the value has no effect."
  type        = map(string)
  default     = {}
  nullable    = false
}
