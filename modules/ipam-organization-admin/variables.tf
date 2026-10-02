variable "delegated_admin_account_id" {
  description = "Network-account ID delegated by the AWS Organizations management account to administer VPC IPAM."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[0-9]{12}$", var.delegated_admin_account_id))
    error_message = "delegated_admin_account_id must be a 12-digit AWS account ID."
  }
}

# Deprecated in 1.1.0, removed in 2.0.0. Neither aws_ram_sharing_with_organization
# nor aws_vpc_ipam_organization_admin_account has a tags argument in the AWS
# provider schema, so this input cannot be wired to anything. Removing it now
# would break every caller that passes it, which semantic versioning reserves
# for a major release; until then it is accepted and ignored.
# tflint-ignore: terraform_unused_declarations
variable "tags" {
  description = "DEPRECATED (removed in 2.0.0): has no effect. Neither resource of this module supports tags; stop passing this input."
  type        = map(string)
  default     = {}
  nullable    = false
}
