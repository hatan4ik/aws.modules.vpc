mock_provider "aws" {}

# The live sandbox-network root's inputs, expressed in v1 form.
variables {
  name       = "sandbox-network-dev"
  cidr_block = "10.64.0.0/16"
  tags       = { Environment = "dev", Owner = "platform" }

  subnets = {
    private = {
      availability_zones = {
        az1 = { availability_zone = "us-east-2a", cidr_block = "10.64.0.0/20" }
        az2 = { availability_zone = "us-east-2b", cidr_block = "10.64.16.0/20" }
      }
    }
  }

  flow_logs = {
    destination = { create_kms_key = true }
    partition   = "aws"
    region      = "us-east-2"
    account_id  = "448871779014"
  }
}

run "private_vpc_matches_the_platform_contract" {
  command = plan

  assert {
    condition     = aws_vpc.this.cidr_block == "10.64.0.0/16" && aws_vpc.this.enable_dns_support == true && aws_vpc.this.enable_dns_hostnames == true && aws_vpc.this.tags["Name"] == "sandbox-network-dev" && aws_vpc.this.tags["Owner"] == "platform"
    error_message = "The VPC must carry the CIDR, DNS settings, Name tag, and caller tags."
  }

  assert {
    condition     = aws_vpc_encryption_control.this[0].mode == "enforce" && !contains(keys(aws_vpc_encryption_control.this[0].tags), "Name")
    error_message = "Encryption control must be enforced and tagged exactly like the v0.1.x root (no Name tag)."
  }

  assert {
    condition     = aws_default_security_group.this.revoke_rules_on_delete == true && length(aws_default_security_group.this.ingress) == 0 && length(aws_default_security_group.this.egress) == 0 && aws_default_security_group.this.tags["Name"] == "sandbox-network-dev-default-deny-all"
    error_message = "The default security group must be managed deny-all with the platform Name."
  }

  assert {
    condition     = output.subnet_cidr_blocks_by_tier["private"]["az1"] == "10.64.0.0/20" && output.subnet_cidr_blocks_by_tier["private"]["az2"] == "10.64.16.0/20" && length(output.route_table_ids_by_tier["private"]) == 2
    error_message = "The private tier must have one subnet and one route table per AZ key."
  }

  assert {
    condition     = output.internet_gateway_id == null && length(output.nat_gateway_ids) == 0 && length(output.interface_endpoint_ids) == 0 && output.endpoint_security_group_id == null
    error_message = "No internet path or endpoints may exist unless declared."
  }

  assert {
    condition     = output.flow_log_group_name == "/aws/vpc/sandbox-network-dev/flow-logs" && output.flow_log_role_name == "sandbox-network-dev-vpc-flow-logs" && output.flow_logs.log_group_name == "/aws/vpc/sandbox-network-dev/flow-logs"
    error_message = "Flow logs must be on with the platform log group and role names, in both output shapes."
  }

  assert {
    condition     = length(keys(output.private_subnets)) == 2 && contains(keys(output.private_subnets), "az1") && output.vpc.cidr == "10.64.0.0/16"
    error_message = "Compatibility outputs must keep the v0.1.x shape."
  }

  assert {
    condition     = length(local.resolved_routes["private"]) == 0 && length(aws_vpc_ipv4_cidr_block_association.this) == 0
    error_message = "A tier without routes has none; no secondary CIDRs by default."
  }
}

run "ipam_allocation_replaces_the_cidr" {
  command = plan

  variables {
    cidr_block = null
    ipam       = { pool_id = "ipam-pool-0123456789abcdef0", netmask_length = 20 }
    subnets = {
      private = {
        availability_zones = {
          az1 = { availability_zone = "us-east-2a", newbits = 4, netnum = 0 }
          az2 = { availability_zone = "us-east-2b", newbits = 4, netnum = 1 }
        }
      }
    }
  }

  assert {
    condition     = aws_vpc.this.ipv4_ipam_pool_id == "ipam-pool-0123456789abcdef0" && aws_vpc.this.ipv4_netmask_length == 20
    error_message = "IPAM inputs must pass through to the VPC."
  }
}

run "warns_when_flow_logs_use_aws_managed_encryption" {
  command = plan

  variables {
    flow_logs = {}
  }

  expect_failures = [check.flow_logs_without_customer_key]
}

run "warns_when_flow_logs_are_disabled" {
  command = plan

  variables {
    flow_logs = null
  }

  expect_failures = [check.flow_logs_disabled]
}

run "warns_on_a_single_az_tier" {
  command = plan

  variables {
    subnets = {
      private = {
        availability_zones = {
          az1 = { availability_zone = "us-east-2a", cidr_block = "10.64.0.0/20" }
        }
      }
    }
  }

  expect_failures = [check.single_az]
}
