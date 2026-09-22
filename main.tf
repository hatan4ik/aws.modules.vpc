data "aws_partition" "current" {}

data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

locals {
  flow_log_group_name = "/aws/vpc/${var.name}/flow-logs"
  flow_log_group_arn  = "arn:${data.aws_partition.current.partition}:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:log-group:${local.flow_log_group_name}"
  flow_log_role_name  = "${var.name}-vpc-flow-logs"

  flow_logs_kms_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowAccountRootAdministration"
        Effect    = "Allow"
        Action    = "kms:*"
        Resource  = "*"
        Principal = { AWS = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root" }
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
        Principal = { Service = "logs.${data.aws_region.current.region}.amazonaws.com" }
        Condition = {
          ArnEquals = {
            "kms:EncryptionContext:aws:logs:arn" = local.flow_log_group_arn
          }
        }
      },
    ]
  })

  flow_logs_assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "vpc-flow-logs.amazonaws.com" }
    }]
  })

  flow_logs_delivery_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogStream",
        "logs:DescribeLogStreams",
        "logs:PutLogEvents",
      ]
      Resource = "${local.flow_log_group_arn}:*"
    }]
  })
}

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(var.tags, {
    Name = var.name
  })

  lifecycle {
    precondition {
      condition     = length(setsubtract(toset(keys(var.private_subnet_cidrs)), toset(keys(var.availability_zones)))) == 0 && length(setsubtract(toset(keys(var.availability_zones)), toset(keys(var.private_subnet_cidrs)))) == 0
      error_message = "private_subnet_cidrs keys must exactly match availability_zones keys."
    }
  }
}

# Enforce encryption for traffic traversing the VPC. The initial sandbox has no
# public egress, NAT gateway, endpoints, or application workload.
resource "aws_vpc_encryption_control" "this" {
  vpc_id = aws_vpc.this.id
  mode   = "enforce"

  tags = var.tags
}

# A new VPC begins with permissive default security-group egress. Manage it
# explicitly as deny-all so workloads must use purpose-specific security groups.
resource "aws_default_security_group" "deny_all" {
  vpc_id                 = aws_vpc.this.id
  revoke_rules_on_delete = true
  ingress                = []
  egress                 = []

  tags = merge(var.tags, {
    Name = "${var.name}-default-deny-all"
  })
}

resource "aws_subnet" "private" {
  for_each = var.private_subnet_cidrs

  vpc_id                  = aws_vpc.this.id
  cidr_block              = each.value
  availability_zone       = var.availability_zones[each.key]
  map_public_ip_on_launch = false

  tags = merge(var.tags, {
    Name = "${var.name}-private-${each.key}"
    Tier = "private"
  })
}

# Each private subnet has an intentionally empty route table. This leaves the
# sandbox isolated until a separately reviewed TGW attachment is introduced.
resource "aws_route_table" "private" {
  for_each = aws_subnet.private

  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.name}-private-${each.key}"
    Tier = "private"
  })
}

resource "aws_route_table_association" "private" {
  for_each = aws_subnet.private

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private[each.key].id
}

resource "aws_kms_key" "flow_logs" {
  description             = "Encrypts CloudWatch VPC Flow Logs for ${var.name}."
  deletion_window_in_days = 30
  enable_key_rotation     = true
  policy                  = local.flow_logs_kms_policy

  tags = merge(var.tags, {
    Name      = "${var.name}-flow-logs"
    DataClass = "network-observability"
  })
}

resource "aws_kms_alias" "flow_logs" {
  name          = "alias/${var.name}-flow-logs"
  target_key_id = aws_kms_key.flow_logs.key_id
}

resource "aws_cloudwatch_log_group" "flow_logs" {
  name              = local.flow_log_group_name
  retention_in_days = var.flow_log_retention_in_days
  kms_key_id        = aws_kms_key.flow_logs.arn

  tags = merge(var.tags, {
    Name = local.flow_log_group_name
  })
}

resource "aws_iam_role" "flow_logs" {
  name               = local.flow_log_role_name
  description        = "Writes VPC Flow Logs for ${var.name} to CloudWatch Logs."
  assume_role_policy = local.flow_logs_assume_role_policy

  tags = var.tags
}

resource "aws_iam_role_policy" "flow_logs_delivery" {
  name   = "${var.name}-flow-logs-delivery"
  role   = aws_iam_role.flow_logs.id
  policy = local.flow_logs_delivery_policy
}

resource "aws_flow_log" "vpc" {
  iam_role_arn             = aws_iam_role.flow_logs.arn
  log_destination          = aws_cloudwatch_log_group.flow_logs.arn
  log_destination_type     = "cloud-watch-logs"
  traffic_type             = "ALL"
  vpc_id                   = aws_vpc.this.id
  max_aggregation_interval = 60

  depends_on = [aws_iam_role_policy.flow_logs_delivery]

  tags = merge(var.tags, {
    Name = "${var.name}-all-traffic"
  })
}
