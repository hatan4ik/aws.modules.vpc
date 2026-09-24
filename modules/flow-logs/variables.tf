variable "name" {
  description = "VPC name; the log group is /aws/vpc/<name>/flow-logs, the delivery role <name>-vpc-flow-logs, the created key alias <name>-flow-logs."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,50}$", var.name))
    error_message = "name must be lowercase, hyphenated, and 3-51 characters."
  }
}

variable "vpc_id" {
  description = "VPC whose traffic is logged."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^vpc-[0-9a-f]+$", var.vpc_id))
    error_message = "vpc_id must be a VPC ID (vpc-...)."
  }
}

variable "destination" {
  description = "Where flow logs go. cloud-watch-logs (default) creates an encrypted log group, or uses an existing one when create_log_group is false and log_group_arn is given; s3 delivers to s3_bucket_arn (bucket ARN, optionally with a prefix) and needs no role."
  type = object({
    type             = optional(string, "cloud-watch-logs")
    log_group_name   = optional(string)
    create_log_group = optional(bool, true)
    log_group_arn    = optional(string)
    log_group_class  = optional(string, "STANDARD")
    kms_key_arn      = optional(string)
    create_kms_key   = optional(bool, false)
    s3_bucket_arn    = optional(string)
    s3_options = optional(object({
      file_format                = optional(string, "plain-text")
      hive_compatible_partitions = optional(bool, false)
      per_hour_partition         = optional(bool, false)
    }))
  })
  default  = {}
  nullable = false

  validation {
    condition     = contains(["cloud-watch-logs", "s3"], var.destination.type)
    error_message = "destination.type must be cloud-watch-logs or s3."
  }

  validation {
    condition     = var.destination.type != "s3" ? true : (var.destination.s3_bucket_arn != null && can(regex("^arn:[^:]+:s3:::", var.destination.s3_bucket_arn)))
    error_message = "destination.s3_bucket_arn (an S3 bucket ARN) is required when destination.type is s3."
  }

  validation {
    condition     = var.destination.type != "cloud-watch-logs" ? true : (var.destination.create_log_group || var.destination.log_group_arn != null)
    error_message = "destination.log_group_arn is required when create_log_group is false."
  }

  validation {
    condition     = !(var.destination.create_kms_key && var.destination.kms_key_arn != null)
    error_message = "destination.create_kms_key and destination.kms_key_arn are mutually exclusive."
  }

  validation {
    condition     = var.destination.kms_key_arn == null ? true : can(regex("^arn:[^:]+:kms:[^:]+:[0-9]{12}:key/.+$", var.destination.kms_key_arn))
    error_message = "destination.kms_key_arn must be a KMS key ARN."
  }

  validation {
    condition     = contains(["STANDARD", "INFREQUENT_ACCESS"], var.destination.log_group_class)
    error_message = "destination.log_group_class must be STANDARD or INFREQUENT_ACCESS."
  }

  validation {
    condition     = var.destination.s3_options == null ? true : contains(["plain-text", "parquet"], var.destination.s3_options.file_format)
    error_message = "destination.s3_options.file_format must be plain-text or parquet."
  }
}

variable "retention_in_days" {
  description = "Retention of the created log group. Network evidence is kept for at least one year."
  type        = number
  default     = 365
  nullable    = false

  validation {
    condition     = contains([365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653], var.retention_in_days)
    error_message = "retention_in_days must be a CloudWatch Logs retention value of at least 365 days."
  }
}

variable "traffic_type" {
  description = "Traffic to capture: ALL, ACCEPT, or REJECT."
  type        = string
  default     = "ALL"
  nullable    = false

  validation {
    condition     = contains(["ALL", "ACCEPT", "REJECT"], var.traffic_type)
    error_message = "traffic_type must be ALL, ACCEPT, or REJECT."
  }
}

variable "max_aggregation_interval" {
  description = "Capture window in seconds: 60 or 600."
  type        = number
  default     = 60
  nullable    = false

  validation {
    condition     = contains([60, 600], var.max_aggregation_interval)
    error_message = "max_aggregation_interval must be 60 or 600."
  }
}

variable "log_format" {
  description = "Custom flow log record format. Null keeps the AWS default fields."
  type        = string
  default     = null
}

variable "role_name" {
  description = "Name of the delivery role for CloudWatch destinations. Defaults to <name>-vpc-flow-logs."
  type        = string
  default     = null
}

variable "role_path" {
  description = "IAM path of the delivery role."
  type        = string
  default     = "/"
  nullable    = false
}

variable "role_permissions_boundary" {
  description = "Permissions boundary policy ARN for the delivery role."
  type        = string
  default     = null
}

variable "kms_key_deletion_window_in_days" {
  description = "Deletion window of the created KMS key."
  type        = number
  default     = 30
  nullable    = false

  validation {
    condition     = var.kms_key_deletion_window_in_days >= 7 && var.kms_key_deletion_window_in_days <= 30
    error_message = "kms_key_deletion_window_in_days must be between 7 and 30."
  }
}

variable "partition" {
  description = "AWS partition used in constructed ARNs. Resolved from the provider when null."
  type        = string
  default     = null
}

variable "region" {
  description = "Region used in constructed ARNs and the CloudWatch Logs service principal. Resolved from the provider when null."
  type        = string
  default     = null
}

variable "account_id" {
  description = "Account ID used in constructed ARNs and the key policy. Resolved from the provider when null."
  type        = string
  default     = null

  validation {
    condition     = var.account_id == null ? true : can(regex("^[0-9]{12}$", var.account_id))
    error_message = "account_id must be a 12-digit AWS account ID."
  }
}

variable "tags" {
  description = "Tags applied to the key, log group, role, and flow log; Name is added by the module."
  type        = map(string)
  default     = {}
  nullable    = false
}
