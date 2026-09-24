# Partition, region, and account are inputs; the data sources are a fallback.
# The KMS key policy must name the log-group ARN before the group exists, so
# the ARN is constructed rather than read from the resource.

data "aws_partition" "current" {
  count = var.partition == null ? 1 : 0
}

data "aws_region" "current" {
  count = var.region == null ? 1 : 0
}

data "aws_caller_identity" "current" {
  count = var.account_id == null ? 1 : 0
}

locals {
  partition  = var.partition != null ? var.partition : data.aws_partition.current[0].partition
  region     = var.region != null ? var.region : data.aws_region.current[0].region
  account_id = var.account_id != null ? var.account_id : data.aws_caller_identity.current[0].account_id

  cloudwatch = var.destination.type == "cloud-watch-logs"

  log_group_name = coalesce(var.destination.log_group_name, "/aws/vpc/${var.name}/flow-logs")
  log_group_arn  = var.destination.create_log_group ? "arn:${local.partition}:logs:${local.region}:${local.account_id}:log-group:${local.log_group_name}" : var.destination.log_group_arn
  role_name      = coalesce(var.role_name, "${var.name}-vpc-flow-logs")

  kms_key_arn = var.destination.create_kms_key ? aws_kms_key.this[0].arn : var.destination.kms_key_arn

  kms_key_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowAccountRootAdministration"
        Effect    = "Allow"
        Action    = "kms:*"
        Resource  = "*"
        Principal = { AWS = "arn:${local.partition}:iam::${local.account_id}:root" }
      },
      {
        Sid    = "AllowCloudWatchLogsForThisLogGroup"
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:Encrypt",
          "kms:GenerateDataKey*",
          "kms:ReEncrypt*",
        ]
        Resource  = "*"
        Principal = { Service = "logs.${local.region}.amazonaws.com" }
        Condition = {
          ArnEquals = {
            "kms:EncryptionContext:aws:logs:arn" = local.log_group_arn
          }
        }
      },
    ]
  })

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "vpc-flow-logs.amazonaws.com" }
    }]
  })

  delivery_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogStream",
        "logs:DescribeLogStreams",
        "logs:PutLogEvents",
      ]
      Resource = "${local.log_group_arn}:*"
    }]
  })
}

resource "aws_kms_key" "this" {
  count = local.cloudwatch && var.destination.create_kms_key ? 1 : 0

  description             = "Encrypts CloudWatch VPC Flow Logs for ${var.name}."
  deletion_window_in_days = var.kms_key_deletion_window_in_days
  enable_key_rotation     = true
  policy                  = local.kms_key_policy

  tags = merge(var.tags, {
    Name      = "${var.name}-flow-logs"
    DataClass = "network-observability"
  })
}

resource "aws_kms_alias" "this" {
  count = local.cloudwatch && var.destination.create_kms_key ? 1 : 0

  name          = "alias/${var.name}-flow-logs"
  target_key_id = aws_kms_key.this[0].key_id
}

resource "aws_cloudwatch_log_group" "this" {
  count = local.cloudwatch && var.destination.create_log_group ? 1 : 0

  name              = local.log_group_name
  retention_in_days = var.retention_in_days
  kms_key_id        = local.kms_key_arn
  log_group_class   = var.destination.log_group_class

  tags = merge(var.tags, {
    Name = local.log_group_name
  })
}

resource "aws_iam_role" "this" {
  count = local.cloudwatch ? 1 : 0

  name                 = local.role_name
  path                 = var.role_path
  description          = "Writes VPC Flow Logs for ${var.name} to CloudWatch Logs."
  permissions_boundary = var.role_permissions_boundary
  assume_role_policy   = local.assume_role_policy

  tags = var.tags
}

resource "aws_iam_role_policy" "this" {
  count = local.cloudwatch ? 1 : 0

  name   = "${var.name}-flow-logs-delivery"
  role   = aws_iam_role.this[0].id
  policy = local.delivery_policy
}

resource "aws_flow_log" "this" {
  vpc_id                   = var.vpc_id
  traffic_type             = var.traffic_type
  max_aggregation_interval = var.max_aggregation_interval
  log_format               = var.log_format
  log_destination_type     = var.destination.type
  log_destination          = local.cloudwatch ? (var.destination.create_log_group ? aws_cloudwatch_log_group.this[0].arn : var.destination.log_group_arn) : var.destination.s3_bucket_arn
  iam_role_arn             = local.cloudwatch ? aws_iam_role.this[0].arn : null

  dynamic "destination_options" {
    for_each = !local.cloudwatch && var.destination.s3_options != null ? [var.destination.s3_options] : []

    content {
      file_format                = destination_options.value.file_format
      hive_compatible_partitions = destination_options.value.hive_compatible_partitions
      per_hour_partition         = destination_options.value.per_hour_partition
    }
  }

  tags = merge(var.tags, {
    Name = "${var.name}-all-traffic"
  })

  depends_on = [aws_iam_role_policy.this]
}
