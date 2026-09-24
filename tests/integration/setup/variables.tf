variable "name_prefix" {
  description = "Prefix of the VPC name under test; a random suffix is appended so concurrent runs never collide. The flow-log role and KMS alias inherit it, which is what the integration IAM policy is scoped to."
  type        = string
  default     = "vpc-it"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,42}$", var.name_prefix))
    error_message = "name_prefix must be 2-43 lowercase alphanumeric characters or hyphens starting with a letter, so the suffixed name satisfies the module's name rule."
  }
}

variable "tags" {
  description = "Tags applied to the VPC under test in addition to the identifying defaults."
  type        = map(string)
  default     = {}
}
