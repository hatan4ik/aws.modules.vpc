mock_provider "aws" {}

variables {
  vpc_id = "vpc-0123456789abcdef0"
  name   = "orders-network"
  tags   = { Environment = "test" }
}

run "creates_gateway_and_public_nat_with_created_eips" {
  command = plan

  variables {
    nat_gateways = {
      az1 = { subnet_id = "subnet-0123456789abcdef0" }
      az2 = { subnet_id = "subnet-0123456789abcdef1" }
    }
  }

  assert {
    condition     = length(aws_internet_gateway.this) == 1 && aws_internet_gateway.this[0].tags["Name"] == "orders-network-igw" && length(aws_egress_only_internet_gateway.this) == 0
    error_message = "The internet gateway must be created and named; no egress-only gateway by default."
  }

  assert {
    condition     = length(aws_nat_gateway.this) == 2 && length(aws_eip.nat) == 2 && aws_nat_gateway.this["az1"].connectivity_type == "public" && aws_nat_gateway.this["az1"].subnet_id == "subnet-0123456789abcdef0" && aws_eip.nat["az1"].domain == "vpc" && aws_eip.nat["az1"].tags["Name"] == "orders-network-nat-az1"
    error_message = "Each public NAT gateway must get its own created Elastic IP."
  }

  assert {
    condition     = length(output.nat_gateway_ids) == 2 && length(output.eip_allocation_ids) == 2 && length(output.nat_gateway_public_ips) == 2 && output.egress_only_internet_gateway_id == null
    error_message = "Outputs must expose gateway and allocation IDs by key."
  }
}

run "uses_supplied_allocation_and_private_nat_without_eips" {
  command = plan

  variables {
    create_egress_only_internet_gateway = true
    nat_gateways = {
      az1  = { subnet_id = "subnet-0123456789abcdef0", allocation_id = "eipalloc-0123456789abcdef0" }
      priv = { subnet_id = "subnet-0123456789abcdef1", connectivity_type = "private", private_ip = "10.0.1.10" }
    }
  }

  assert {
    condition     = length(aws_eip.nat) == 0 && aws_nat_gateway.this["az1"].allocation_id == "eipalloc-0123456789abcdef0" && aws_nat_gateway.this["priv"].connectivity_type == "private" && aws_nat_gateway.this["priv"].allocation_id == null && aws_nat_gateway.this["priv"].private_ip == "10.0.1.10"
    error_message = "Supplied allocations and private NAT gateways must not create Elastic IPs."
  }

  assert {
    condition     = length(aws_egress_only_internet_gateway.this) == 1 && length(output.nat_gateway_public_ips) == 1
    error_message = "The egress-only gateway must render when requested and private gateways have no public IP."
  }
}

run "internet_gateway_only" {
  command = plan

  assert {
    condition     = length(aws_internet_gateway.this) == 1 && length(aws_nat_gateway.this) == 0 && length(aws_eip.nat) == 0
    error_message = "No NAT gateways may be created unless declared."
  }
}

run "rejects_public_nat_without_internet_gateway" {
  command = plan

  variables {
    create_internet_gateway = false
    nat_gateways = {
      az1 = { subnet_id = "subnet-0123456789abcdef0" }
    }
  }

  expect_failures = [aws_nat_gateway.this]
}

run "rejects_private_nat_with_allocation" {
  command = plan

  variables {
    nat_gateways = {
      priv = { subnet_id = "subnet-0123456789abcdef0", connectivity_type = "private", allocation_id = "eipalloc-0123456789abcdef0" }
    }
  }

  expect_failures = [var.nat_gateways]
}

run "rejects_unknown_connectivity_type" {
  command = plan

  variables {
    nat_gateways = {
      az1 = { subnet_id = "subnet-0123456789abcdef0", connectivity_type = "hybrid" }
    }
  }

  expect_failures = [var.nat_gateways]
}
