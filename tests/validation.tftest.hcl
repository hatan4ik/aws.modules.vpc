mock_provider "aws" {}

variables {
  name       = "orders-network"
  cidr_block = "10.0.0.0/16"
  flow_logs  = { partition = "aws", region = "us-east-2", account_id = "123456789012", destination = { create_kms_key = true } }

  subnets = {
    private = {
      availability_zones = {
        az1 = { availability_zone = "us-east-2a", cidr_block = "10.0.0.0/20" }
        az2 = { availability_zone = "us-east-2b", cidr_block = "10.0.16.0/20" }
      }
    }
  }
}

run "rejects_cidr_and_ipam_together" {
  command = plan
  variables {
    ipam = { pool_id = "ipam-pool-0123456789abcdef0", netmask_length = 20 }
  }
  expect_failures = [aws_vpc.this]
}

run "rejects_neither_cidr_nor_ipam" {
  command = plan
  variables {
    cidr_block = null
  }
  expect_failures = [aws_vpc.this]
}

run "rejects_empty_tiers" {
  command = plan
  variables {
    subnets = {}
  }
  expect_failures = [var.subnets]
}

run "rejects_route_with_two_targets" {
  command = plan
  variables {
    subnets = {
      private = {
        availability_zones = { az1 = { availability_zone = "us-east-2a", cidr_block = "10.0.0.0/20" }, az2 = { availability_zone = "us-east-2b", cidr_block = "10.0.16.0/20" } }
        routes             = { bad = { destination_cidr_block = "10.0.0.0/8", transit_gateway_id = "tgw-0123456789abcdef0", internet_gateway = true } }
      }
    }
  }
  expect_failures = [var.subnets]
}

run "rejects_nat_gateway_in_undeclared_subnet" {
  command = plan
  variables {
    internet = { nat_gateways = { az1 = { subnet = "public/az1" } } }
  }
  expect_failures = [aws_vpc.this, check.internet_path_declared]
}

run "rejects_route_to_unknown_nat_gateway_key" {
  command = plan
  variables {
    internet = { nat_gateways = { az1 = { subnet = "private/az1" } } }
    subnets = {
      private = {
        availability_zones  = { az1 = { availability_zone = "us-east-2a", cidr_block = "10.0.0.0/20" }, az2 = { availability_zone = "us-east-2b", cidr_block = "10.0.16.0/20" } }
        allow_default_route = true
        routes              = { internet = { destination_cidr_block = "0.0.0.0/0", nat_gateway_key = "az9" } }
      }
    }
  }
  expect_failures = [aws_vpc.this, check.internet_path_declared]
}

run "rejects_internet_gateway_route_without_internet" {
  command = plan
  variables {
    subnets = {
      public = {
        availability_zones  = { az1 = { availability_zone = "us-east-2a", cidr_block = "10.0.0.0/20" }, az2 = { availability_zone = "us-east-2b", cidr_block = "10.0.16.0/20" } }
        allow_default_route = true
        routes              = { internet = { destination_cidr_block = "0.0.0.0/0", internet_gateway = true } }
      }
    }
  }
  expect_failures = [aws_vpc.this]
}

run "rejects_endpoint_in_undeclared_tier" {
  command = plan
  variables {
    endpoints = { interface = { sts = { service_name = "com.amazonaws.us-east-2.sts", subnet_tier = "isolated" } } }
  }
  expect_failures = [aws_vpc.this]
}

run "rejects_malformed_nat_subnet_reference" {
  command = plan
  variables {
    internet = { nat_gateways = { az1 = { subnet = "public" } } }
  }
  expect_failures = [var.internet]
}

run "rejects_invalid_encryption_mode" {
  command = plan
  variables {
    vpc_encryption_control = "audit"
  }
  expect_failures = [var.vpc_encryption_control]
}

run "rejects_invalid_ipam_netmask" {
  command = plan
  variables {
    cidr_block = null
    ipam       = { pool_id = "ipam-pool-0123456789abcdef0", netmask_length = 8 }
  }
  expect_failures = [var.ipam]
}
