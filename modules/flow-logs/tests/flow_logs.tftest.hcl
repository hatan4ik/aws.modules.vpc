mock_provider "aws" {
  mock_data "aws_partition" {
    defaults = { partition = "aws" }
  }
  mock_data "aws_region" {
    defaults = { region = "us-east-2" }
  }
  mock_data "aws_caller_identity" {
    defaults = { account_id = "448871779014" }
  }
}

variables {
  name       = "sandbox-network-dev"
  vpc_id     = "vpc-0123456789abcdef0"
  partition  = "aws"
  region     = "us-east-2"
  account_id = "123456789012"
  tags       = { Environment = "dev" }
}

run "cloudwatch_destination_with_created_key_matches_the_platform_layout" {
  command = plan

  variables {
    destination = { create_kms_key = true }
  }

  assert {
    condition     = aws_cloudwatch_log_group.this[0].name == "/aws/vpc/sandbox-network-dev/flow-logs" && aws_cloudwatch_log_group.this[0].retention_in_days == 365 && aws_cloudwatch_log_group.this[0].tags["Name"] == "/aws/vpc/sandbox-network-dev/flow-logs"
    error_message = "The log group must follow /aws/vpc/<name>/flow-logs with one-year retention."
  }

  assert {
    condition     = aws_kms_key.this[0].enable_key_rotation == true && aws_kms_key.this[0].deletion_window_in_days == 30 && aws_kms_key.this[0].tags["Name"] == "sandbox-network-dev-flow-logs" && aws_kms_key.this[0].tags["DataClass"] == "network-observability" && aws_kms_alias.this[0].name == "alias/sandbox-network-dev-flow-logs"
    error_message = "The created key must be rotated, named, classified, and aliased like the platform key."
  }

  assert {
    condition     = jsondecode(aws_kms_key.this[0].policy).Statement[1].Principal.Service == "logs.us-east-2.amazonaws.com" && jsondecode(aws_kms_key.this[0].policy).Statement[1].Condition.ArnEquals["kms:EncryptionContext:aws:logs:arn"] == "arn:aws:logs:us-east-2:123456789012:log-group:/aws/vpc/sandbox-network-dev/flow-logs" && jsondecode(aws_kms_key.this[0].policy).Statement[0].Principal.AWS == "arn:aws:iam::123456789012:root"
    error_message = "The key policy must scope CloudWatch Logs to this log group and keep root administration."
  }

  assert {
    condition     = aws_iam_role.this[0].name == "sandbox-network-dev-vpc-flow-logs" && jsondecode(aws_iam_role.this[0].assume_role_policy).Statement[0].Principal.Service == "vpc-flow-logs.amazonaws.com" && aws_iam_role_policy.this[0].name == "sandbox-network-dev-flow-logs-delivery" && jsondecode(aws_iam_role_policy.this[0].policy).Statement[0].Resource == "arn:aws:logs:us-east-2:123456789012:log-group:/aws/vpc/sandbox-network-dev/flow-logs:*"
    error_message = "The delivery role and policy must match the platform names and target only this log group."
  }

  assert {
    condition     = aws_flow_log.this.traffic_type == "ALL" && aws_flow_log.this.max_aggregation_interval == 60 && aws_flow_log.this.log_destination_type == "cloud-watch-logs" && aws_flow_log.this.tags["Name"] == "sandbox-network-dev-all-traffic"
    error_message = "The flow log must capture all traffic at 60-second aggregation with the platform Name."
  }

  assert {
    condition     = output.log_group_name == "/aws/vpc/sandbox-network-dev/flow-logs" && output.role_name == "sandbox-network-dev-vpc-flow-logs" && output.destination_type == "cloud-watch-logs"
    error_message = "Outputs must expose the log group, role, and destination type."
  }
}

run "resolves_partition_region_and_account_from_the_provider_when_not_given" {
  command = plan

  variables {
    partition   = null
    region      = null
    account_id  = null
    destination = { create_kms_key = true }
  }

  assert {
    condition     = jsondecode(aws_kms_key.this[0].policy).Statement[0].Principal.AWS == "arn:aws:iam::448871779014:root" && output.log_group_arn == "arn:aws:logs:us-east-2:448871779014:log-group:/aws/vpc/sandbox-network-dev/flow-logs"
    error_message = "Missing inputs must fall back to the provider's partition, region, and account."
  }
}

run "uses_a_supplied_key_and_creates_no_key" {
  command = plan

  variables {
    destination = { kms_key_arn = "arn:aws:kms:us-east-2:123456789012:key/11111111-1111-1111-1111-111111111111" }
  }

  assert {
    condition     = length(aws_kms_key.this) == 0 && length(aws_kms_alias.this) == 0 && aws_cloudwatch_log_group.this[0].kms_key_id == "arn:aws:kms:us-east-2:123456789012:key/11111111-1111-1111-1111-111111111111" && output.kms_key_alias_arn == null
    error_message = "A supplied key must encrypt the log group and no key may be created."
  }
}

run "uses_an_existing_log_group" {
  command = plan

  variables {
    destination = { create_log_group = false, log_group_arn = "arn:aws:logs:us-east-2:123456789012:log-group:/platform/flow-logs" }
  }

  assert {
    condition     = length(aws_cloudwatch_log_group.this) == 0 && aws_flow_log.this.log_destination == "arn:aws:logs:us-east-2:123456789012:log-group:/platform/flow-logs" && jsondecode(aws_iam_role_policy.this[0].policy).Statement[0].Resource == "arn:aws:logs:us-east-2:123456789012:log-group:/platform/flow-logs:*"
    error_message = "An existing log group must be used as-is and the role scoped to it."
  }
}

run "s3_destination_needs_no_role_or_log_group" {
  command = plan

  variables {
    destination = {
      type          = "s3"
      s3_bucket_arn = "arn:aws:s3:::flow-logs-archive/vpc/"
      s3_options    = { file_format = "parquet", hive_compatible_partitions = true, per_hour_partition = true }
    }
  }

  assert {
    condition     = length(aws_iam_role.this) == 0 && length(aws_cloudwatch_log_group.this) == 0 && aws_flow_log.this.log_destination_type == "s3" && aws_flow_log.this.log_destination == "arn:aws:s3:::flow-logs-archive/vpc/" && aws_flow_log.this.iam_role_arn == null
    error_message = "S3 delivery must not create a role or log group."
  }

  assert {
    condition     = aws_flow_log.this.destination_options[0].file_format == "parquet" && aws_flow_log.this.destination_options[0].hive_compatible_partitions == true && output.role_arn == null && output.log_group_name == null
    error_message = "S3 destination options must render and CloudWatch outputs must be null."
  }
}

run "custom_format_and_aggregation_pass_through" {
  command = plan

  variables {
    log_format               = "$${version} $${srcaddr} $${dstaddr} $${action}"
    max_aggregation_interval = 600
    traffic_type             = "REJECT"
    role_name                = "custom-delivery"
    role_path                = "/network/"
  }

  assert {
    condition     = aws_flow_log.this.log_format == "$${version} $${srcaddr} $${dstaddr} $${action}" && aws_flow_log.this.max_aggregation_interval == 600 && aws_flow_log.this.traffic_type == "REJECT" && aws_iam_role.this[0].name == "custom-delivery" && aws_iam_role.this[0].path == "/network/"
    error_message = "Format, aggregation, traffic type, and role naming must pass through."
  }
}

run "rejects_s3_without_bucket" {
  command = plan

  variables {
    destination = { type = "s3" }
  }

  expect_failures = [var.destination]
}

run "rejects_existing_log_group_without_arn" {
  command = plan

  variables {
    destination = { create_log_group = false }
  }

  expect_failures = [var.destination]
}

run "rejects_created_and_supplied_key_together" {
  command = plan

  variables {
    destination = { create_kms_key = true, kms_key_arn = "arn:aws:kms:us-east-2:123456789012:key/11111111-1111-1111-1111-111111111111" }
  }

  expect_failures = [var.destination]
}

run "rejects_retention_below_one_year" {
  command = plan

  variables {
    retention_in_days = 90
  }

  expect_failures = [var.retention_in_days]
}
