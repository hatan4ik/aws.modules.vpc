# Integration suite: real apply in the caller's own account.
#
# Requires AWS credentials and a region from the environment (for example
# AWS_PROFILE and AWS_REGION, or the OIDC role assumed by the integration
# workflow). Nothing is hard-coded: the setup module resolves two Availability
# Zones and a unique name, the module creates a private-only VPC with its
# defaults (VPC Encryption Control enforced, deny-all default security group,
# flow logs to CloudWatch Logs under a customer-managed key), two private
# subnets derived with newbits and netnum, and an S3 gateway endpoint on the
# private route tables. The results are asserted against the real API and
# everything is destroyed at the end of the file. The KMS key is scheduled
# for deletion with the shortest window AWS allows (7 days) and lingers,
# unusable and free of charge, until then.
#
# Run: terraform init -backend=false -test-directory=tests/integration
#      terraform test -test-directory=tests/integration -filter=tests/integration/smoke.tftest.hcl

provider "aws" {}

run "setup" {
  module {
    source = "./tests/integration/setup"
  }

  variables {
    name_prefix = "vpc-it"
  }
}

run "smoke" {
  variables {
    name       = run.setup.name
    cidr_block = "10.99.0.0/16"
    tags       = run.setup.tags

    subnets = {
      private = {
        availability_zones = {
          az1 = { availability_zone = run.setup.availability_zones[0], newbits = 4, netnum = 0 }
          az2 = { availability_zone = run.setup.availability_zones[1], newbits = 4, netnum = 1 }
        }
      }
    }

    endpoints = {
      gateway = {
        s3 = { service_name = "com.amazonaws.${run.setup.region}.s3", route_table_tiers = ["private"] }
      }
    }

    flow_logs = {
      destination                     = { create_kms_key = true }
      kms_key_deletion_window_in_days = 7
    }
  }

  assert {
    condition     = startswith(output.vpc_id, "vpc-") && output.cidr_block == "10.99.0.0/16" && output.vpc.id == output.vpc_id && output.vpc.cidr == output.cidr_block
    error_message = "The VPC must exist with the requested CIDR, in both output shapes."
  }

  assert {
    condition     = aws_vpc.this.enable_dns_support && aws_vpc.this.enable_dns_hostnames && aws_vpc.this.enable_network_address_usage_metrics && aws_vpc.this.tags["Name"] == run.setup.name && aws_vpc.this.tags["IntegrationTest"] == "aws.modules.vpc"
    error_message = "The real API must accept the VPC defaults and keep the Name and caller tags."
  }

  assert {
    condition     = output.encryption_control_mode == "enforce" && aws_vpc_encryption_control.this[0].mode == "enforce"
    error_message = "VPC Encryption Control must be enforced by default."
  }

  assert {
    condition     = startswith(output.default_security_group_id, "sg-") && length(aws_default_security_group.this.ingress) == 0 && length(aws_default_security_group.this.egress) == 0
    error_message = "The default security group must be managed deny-all."
  }

  assert {
    condition     = output.subnet_cidr_blocks_by_tier["private"]["az1"] == "10.99.0.0/20" && output.subnet_cidr_blocks_by_tier["private"]["az2"] == "10.99.16.0/20" && output.subnets["private"]["az1"].cidr_block == "10.99.0.0/20"
    error_message = "Subnet CIDRs derived with newbits and netnum must match what AWS created."
  }

  assert {
    condition     = output.subnets["private"]["az1"].availability_zone == run.setup.availability_zones[0] && output.subnets["private"]["az2"].availability_zone == run.setup.availability_zones[1]
    error_message = "Each subnet must land in the Availability Zone the fixture resolved."
  }

  assert {
    condition     = length(output.subnet_ids_by_tier["private"]) == 2 && length(output.route_table_ids_by_tier["private"]) == 2 && alltrue([for subnet in values(output.subnets["private"]) : startswith(subnet.id, "subnet-") && startswith(subnet.route_table_id, "rtb-")])
    error_message = "The private tier must have one subnet and one route table per Availability Zone."
  }

  assert {
    condition     = length(keys(output.private_subnets)) == 2 && output.private_subnets["az1"].id == output.subnets["private"]["az1"].id && output.private_subnets["az1"].route_table_id == output.subnets["private"]["az1"].route_table_id
    error_message = "The compatibility output must expose the private tier in the v0.1.x shape."
  }

  assert {
    condition     = length(output.gateway_endpoint_ids) == 1 && startswith(output.gateway_endpoint_ids["s3"], "vpce-") && startswith(output.gateway_endpoint_prefix_list_ids["s3"], "pl-")
    error_message = "The S3 gateway endpoint must exist and expose its managed prefix list."
  }

  assert {
    condition     = length(output.interface_endpoint_ids) == 0 && startswith(output.endpoint_security_group_id, "sg-")
    error_message = "No interface endpoint may exist, while the default endpoint security group is created."
  }

  assert {
    condition     = output.internet_gateway_id == null && output.egress_only_internet_gateway_id == null && length(output.nat_gateway_ids) == 0 && length(output.nat_gateway_public_ips) == 0
    error_message = "A VPC without an internet declaration must have no internet path."
  }

  assert {
    condition     = startswith(output.flow_log_id, "fl-") && output.flow_log_group_name == "/aws/vpc/${run.setup.name}/flow-logs" && startswith(output.flow_log_group_arn, "arn:")
    error_message = "Flow logs must deliver to the module-named CloudWatch log group."
  }

  assert {
    condition     = startswith(output.flow_log_kms_key_arn, "arn:") && output.flow_log_role_name == "${run.setup.name}-vpc-flow-logs" && startswith(output.flow_log_role_arn, "arn:")
    error_message = "The customer-managed key and the delivery role must have been created with the module names."
  }

  assert {
    condition     = output.flow_logs.id == output.flow_log_id && output.flow_logs.log_group_name == output.flow_log_group_name && output.flow_logs.kms_key_arn == output.flow_log_kms_key_arn && output.flow_logs.role_arn == output.flow_log_role_arn
    error_message = "The compatibility flow_logs output must mirror the flat outputs."
  }
}
