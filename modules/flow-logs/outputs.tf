output "id" {
  description = "Flow log ID."
  value       = aws_flow_log.this.id
}

output "arn" {
  description = "Flow log ARN."
  value       = aws_flow_log.this.arn
}

output "log_group_name" {
  description = "CloudWatch log group name for cloud-watch-logs destinations, else null."
  value       = local.cloudwatch ? local.log_group_name : null
}

output "log_group_arn" {
  description = "CloudWatch log group ARN for cloud-watch-logs destinations, else null."
  value       = local.cloudwatch ? local.log_group_arn : null
}

output "kms_key_arn" {
  description = "KMS key encrypting the log group (created or supplied), else null."
  value       = local.cloudwatch ? local.kms_key_arn : null
}

output "kms_key_alias_arn" {
  description = "ARN of the created key alias, else null."
  value       = var.destination.create_kms_key ? aws_kms_alias.this[0].arn : null
}

output "role_arn" {
  description = "Delivery role ARN for cloud-watch-logs destinations, else null."
  value       = local.cloudwatch ? aws_iam_role.this[0].arn : null
}

output "role_name" {
  description = "Delivery role name for cloud-watch-logs destinations, else null."
  value       = local.cloudwatch ? local.role_name : null
}

output "destination_type" {
  description = "cloud-watch-logs or s3."
  value       = var.destination.type
}
