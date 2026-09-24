mock_provider "aws" {}

variables {
  name       = "orders-network"
  cidr_block = "10.0.0.0/16"
  tags       = { Environment = "test" }

  flow_logs = {
    destination = { kms_key_arn = "arn:aws:kms:us-east-2:123456789012:key/11111111-1111-1111-1111-111111111111" }
    partition   = "aws"
    region      = "us-east-2"
    account_id  = "123456789012"
  }

  subnets = {
    public = {
      availability_zones = {
        az1 = { availability_zone = "us-east-2a", newbits = 8, netnum = 0 }
        az2 = { availability_zone = "us-east-2b", newbits = 8, netnum = 1 }
      }
      map_public_ip_on_launch = false
      allow_default_route     = true
      routes = {
        internet = { destination_cidr_block = "0.0.0.0/0", internet_gateway = true }
      }
    }
    private = {
      availability_zones = {
        az1 = { availability_zone = "us-east-2a", newbits = 4, netnum = 1 }
        az2 = { availability_zone = "us-east-2b", newbits = 4, netnum = 2 }
      }
      allow_default_route = true
      routes = {
        internet = { destination_cidr_block = "0.0.0.0/0", nat_gateway_key = "az1" }
        hub      = { destination_cidr_block = "10.0.0.0/8", transit_gateway_id = "tgw-0123456789abcdef0" }
      }
    }
    transit = {
      availability_zones = {
        az1 = { availability_zone = "us-east-2a", cidr_block = "10.0.255.0/28" }
        az2 = { availability_zone = "us-east-2b", cidr_block = "10.0.255.16/28" }
      }
      route_tables = "shared"
    }
  }

  internet = {
    nat_gateways = {
      az1 = { subnet = "public/az1" }
    }
  }

  endpoints = {
    interface = {
      ecr-api = { service_name = "com.amazonaws.us-east-2.ecr.api", subnet_tier = "private" }
    }
    gateway = {
      s3 = { service_name = "com.amazonaws.us-east-2.s3", route_table_tiers = ["private", "transit"] }
    }
  }
}

run "composes_tiers_gateways_routes_and_endpoints" {
  command = plan

  assert {
    condition     = output.subnet_cidr_blocks_by_tier["public"]["az1"] == "10.0.0.0/24" && output.subnet_cidr_blocks_by_tier["private"]["az2"] == "10.0.32.0/20" && output.subnet_cidr_blocks_by_tier["transit"]["az1"] == "10.0.255.0/28"
    error_message = "Derived and explicit CIDRs must resolve per tier."
  }

  assert {
    condition     = length(output.route_table_ids_by_tier["transit"]) == 1 && contains(keys(output.route_table_ids_by_tier["transit"]), "shared") && length(output.route_table_ids_by_tier["private"]) == 2
    error_message = "Shared and per-AZ route tables must follow the tier setting."
  }

  assert {
    condition     = length(local.nat_gateways) == 1 && contains(keys(local.nat_gateways), "az1") && local.nat_gateways["az1"].connectivity_type == "public"
    error_message = "NAT gateway subnet references must resolve to the public tier."
  }

  assert {
    condition     = local.resolved_routes["private"]["hub"].transit_gateway_id == "tgw-0123456789abcdef0" && local.resolved_routes["private"]["internet"].gateway_id == null && local.resolved_routes["public"]["internet"].nat_gateway_id == null
    error_message = "Explicit route targets must pass through and unrelated targets stay null."
  }

  assert {
    condition     = length(output.interface_endpoint_ids) == 1 && length(output.gateway_endpoint_ids) == 1 && length(output.nat_gateway_ids) == 1
    error_message = "Endpoint and NAT gateway outputs must be keyed by their declared keys."
  }

  expect_failures = [check.internet_path_declared]
}

run "secondary_cidrs_associate_with_the_vpc" {
  command = plan

  variables {
    secondary_cidr_blocks = ["10.1.0.0/16", "10.2.0.0/16"]
    internet              = null
    endpoints             = null
    subnets = {
      private = {
        availability_zones = {
          az1 = { availability_zone = "us-east-2a", cidr_block = "10.0.0.0/20" }
          az2 = { availability_zone = "us-east-2b", cidr_block = "10.0.16.0/20" }
        }
      }
    }
  }

  assert {
    condition     = length(aws_vpc_ipv4_cidr_block_association.this) == 2 && aws_vpc_ipv4_cidr_block_association.this["10.1.0.0/16"].cidr_block == "10.1.0.0/16" && output.secondary_cidr_blocks == tolist(["10.1.0.0/16", "10.2.0.0/16"]) && length(local.vpc_cidr_blocks) == 3
    error_message = "Secondary CIDRs must be associated and exposed."
  }
}

run "encryption_control_can_be_left_unmanaged" {
  command = plan

  variables {
    vpc_encryption_control = null
    internet               = null
    endpoints              = null
    subnets = {
      private = {
        availability_zones = {
          az1 = { availability_zone = "us-east-2a", cidr_block = "10.0.0.0/20" }
          az2 = { availability_zone = "us-east-2b", cidr_block = "10.0.16.0/20" }
        }
      }
    }
  }

  assert {
    condition     = length(aws_vpc_encryption_control.this) == 0 && output.encryption_control_mode == null
    error_message = "A null encryption control mode must create no resource."
  }
}
