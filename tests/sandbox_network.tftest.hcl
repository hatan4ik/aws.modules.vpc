mock_provider "aws" {}

variables {
  name     = "test-sandbox-network"
  vpc_cidr = "10.64.0.0/16"
  availability_zones = {
    az1 = "us-east-2a"
    az2 = "us-east-2b"
  }
  private_subnet_cidrs = {
    az1 = "10.64.0.0/20"
    az2 = "10.64.16.0/20"
  }
  flow_log_retention_in_days = 365
  tags = {
    Environment = "dev"
    ManagedBy   = "terraform"
    Root        = "sandbox-network"
  }
}

run "plans_an_isolated_two_az_network" {
  command = plan

  assert {
    condition     = length(aws_subnet.private) == 2 && length(aws_route_table.private) == 2
    error_message = "The sandbox network must plan one private subnet and route table per AZ."
  }

  assert {
    condition     = aws_vpc_encryption_control.this.mode == "enforce"
    error_message = "VPC encryption control must remain in enforce mode."
  }

  assert {
    condition     = aws_kms_key.flow_logs.enable_key_rotation && aws_kms_key.flow_logs.deletion_window_in_days == 30
    error_message = "The dedicated VPC Flow Logs KMS key must rotate and retain a recovery window."
  }

  assert {
    condition     = length(aws_default_security_group.deny_all.egress) == 0 && length(aws_default_security_group.deny_all.ingress) == 0
    error_message = "The default security group must remain deny-all."
  }
}

run "rejects_a_single_az_network" {
  command = plan

  variables {
    availability_zones = {
      az1 = "us-east-2a"
    }
    private_subnet_cidrs = {
      az1 = "10.64.0.0/20"
    }
  }

  expect_failures = [var.availability_zones]
}
