# Integration suite: a real internet path in the caller's own account.
#
# Public and private tiers across two Availability Zones, an internet gateway,
# one public NAT gateway in public/az1, a public default route through the
# internet gateway, a private default route through the NAT gateway, and flow
# logs under a customer-managed key. The NAT gateway and its Elastic IP cost
# a few cents for the minutes they exist. VPC Encryption Control runs in
# monitor mode here because enforce mode rejects the unencrypted internet
# path this suite deliberately declares. Everything is destroyed at the end
# of the file; the KMS key lingers pending deletion for 7 days, unusable and
# free of charge.
#
# Run: terraform init -backend=false -test-directory=tests/integration
#      terraform test -test-directory=tests/integration -filter=tests/integration/nat-egress.tftest.hcl

provider "aws" {}

run "setup" {
  module {
    source = "./tests/integration/setup"
  }

  variables {
    name_prefix = "vpc-nat"
  }
}

run "nat_egress" {
  variables {
    name                   = run.setup.name
    cidr_block             = "10.98.0.0/16"
    vpc_encryption_control = "monitor"
    tags                   = run.setup.tags

    subnets = {
      public = {
        availability_zones = {
          az1 = { availability_zone = run.setup.availability_zones[0], newbits = 8, netnum = 0 }
          az2 = { availability_zone = run.setup.availability_zones[1], newbits = 8, netnum = 1 }
        }
        allow_default_route = true
        routes = {
          internet = { destination_cidr_block = "0.0.0.0/0", internet_gateway = true }
        }
      }
      private = {
        availability_zones = {
          az1 = { availability_zone = run.setup.availability_zones[0], newbits = 4, netnum = 1 }
          az2 = { availability_zone = run.setup.availability_zones[1], newbits = 4, netnum = 2 }
        }
        allow_default_route = true
        routes = {
          internet = { destination_cidr_block = "0.0.0.0/0", nat_gateway_key = "az1" }
        }
      }
    }

    internet = {
      nat_gateways = {
        az1 = { subnet = "public/az1" }
      }
    }

    flow_logs = {
      destination                     = { create_kms_key = true }
      kms_key_deletion_window_in_days = 7
    }
  }

  assert {
    condition     = startswith(output.internet_gateway_id, "igw-") && output.egress_only_internet_gateway_id == null
    error_message = "An internet gateway and no egress-only gateway must exist."
  }

  assert {
    condition     = length(output.nat_gateway_ids) == 1 && startswith(output.nat_gateway_ids["az1"], "nat-")
    error_message = "Exactly one NAT gateway, keyed az1, must exist."
  }

  assert {
    condition     = length(output.nat_gateway_public_ips) == 1 && can(cidrhost("${output.nat_gateway_public_ips["az1"]}/32", 0))
    error_message = "The public NAT gateway must expose the IPv4 address of its Elastic IP."
  }

  assert {
    condition     = length(output.route_table_ids_by_tier["public"]) == 2 && length(output.route_table_ids_by_tier["private"]) == 2 && length(output.subnet_ids_by_tier["public"]) == 2 && length(output.subnet_ids_by_tier["private"]) == 2
    error_message = "Both tiers must have one subnet and one route table per Availability Zone."
  }

  assert {
    condition     = output.subnet_cidr_blocks_by_tier["public"]["az1"] == "10.98.0.0/24" && output.subnet_cidr_blocks_by_tier["public"]["az2"] == "10.98.1.0/24" && output.subnet_cidr_blocks_by_tier["private"]["az1"] == "10.98.16.0/20" && output.subnet_cidr_blocks_by_tier["private"]["az2"] == "10.98.32.0/20"
    error_message = "Public /24 and private /20 subnets must be carved from the VPC CIDR as declared."
  }

  assert {
    condition     = output.subnets["public"]["az1"].availability_zone == run.setup.availability_zones[0] && output.subnets["private"]["az2"].availability_zone == run.setup.availability_zones[1]
    error_message = "Each subnet must land in the Availability Zone the fixture resolved."
  }

  assert {
    condition     = length(local.resolved_routes["public"]) == 1 && local.resolved_routes["public"]["internet"].gateway_id == output.internet_gateway_id && local.resolved_routes["public"]["internet"].nat_gateway_id == null
    error_message = "The public default route must target the internet gateway created here."
  }

  assert {
    condition     = length(local.resolved_routes["private"]) == 1 && local.resolved_routes["private"]["internet"].nat_gateway_id == output.nat_gateway_ids["az1"] && local.resolved_routes["private"]["internet"].gateway_id == null
    error_message = "The private default route must target the NAT gateway created here."
  }

  assert {
    condition     = output.encryption_control_mode == "monitor" && aws_vpc_encryption_control.this[0].mode == "monitor"
    error_message = "VPC Encryption Control must run in monitor mode for a VPC with an internet path."
  }

  assert {
    condition     = startswith(output.flow_log_id, "fl-") && output.flow_log_group_name == "/aws/vpc/${run.setup.name}/flow-logs" && startswith(output.flow_log_kms_key_arn, "arn:") && output.flow_log_role_name == "${run.setup.name}-vpc-flow-logs"
    error_message = "Flow logs must deliver to the module-named log group under the created key and role."
  }

  # The advisory check that flags an internet path is expected here: the
  # suite declares one on purpose.
  expect_failures = [check.internet_path_declared]
}
