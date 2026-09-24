mock_provider "aws" {}

variables {
  vpc_id         = "vpc-0123456789abcdef0"
  vpc_cidr_block = "10.64.0.0/16"
  name           = "sandbox-network-dev"
  tier           = "private"
  tags           = { Environment = "dev" }

  availability_zones = {
    az1 = { availability_zone = "us-east-2a", cidr_block = "10.64.0.0/20" }
    az2 = { availability_zone = "us-east-2b", cidr_block = "10.64.16.0/20" }
  }
}

run "creates_one_route_table_per_subnet_with_platform_names" {
  command = plan

  assert {
    condition     = length(aws_subnet.this) == 2 && length(aws_route_table.this) == 2 && length(aws_route_table_association.this) == 2
    error_message = "per_az must create one subnet, one route table, and one association per AZ key."
  }

  assert {
    condition     = aws_subnet.this["az1"].cidr_block == "10.64.0.0/20" && aws_subnet.this["az1"].availability_zone == "us-east-2a" && aws_subnet.this["az1"].map_public_ip_on_launch == false
    error_message = "Explicit CIDRs and AZs must pass through and subnets must be private by default."
  }

  assert {
    condition     = aws_subnet.this["az1"].tags["Name"] == "sandbox-network-dev-private-az1" && aws_subnet.this["az1"].tags["Tier"] == "private" && aws_subnet.this["az1"].tags["Environment"] == "dev"
    error_message = "Subnets must carry the platform Name and Tier tags and the caller tags."
  }

  assert {
    condition     = aws_route_table.this["az2"].tags["Name"] == "sandbox-network-dev-private-az2" && aws_route_table.this["az2"].tags["Tier"] == "private"
    error_message = "Route tables must carry the same Name and Tier tags."
  }

  assert {
    condition     = output.subnet_cidr_blocks["az2"] == "10.64.16.0/20" && output.tier == "private"
    error_message = "CIDR blocks must be exposed at plan time."
  }
}

run "derives_cidrs_from_the_vpc_and_shares_one_route_table" {
  command = plan

  variables {
    route_tables = "shared"
    availability_zones = {
      az1 = { availability_zone = "us-east-2a", newbits = 4, netnum = 0 }
      az2 = { availability_zone = "us-east-2b", newbits = 4, netnum = 1 }
    }
  }

  assert {
    condition     = aws_subnet.this["az1"].cidr_block == "10.64.0.0/20" && aws_subnet.this["az2"].cidr_block == "10.64.16.0/20"
    error_message = "newbits and netnum must be resolved against the VPC CIDR."
  }

  assert {
    condition     = length(aws_route_table.this) == 1 && aws_route_table.this["shared"].tags["Name"] == "sandbox-network-dev-private"
    error_message = "shared must create exactly one route table named after the tier."
  }

  assert {
    condition     = length(output.route_table_ids) == 1 && contains(keys(output.route_table_ids), "shared")
    error_message = "The shared route table must be exposed under the shared key."
  }
}

run "public_tier_settings_pass_through" {
  command = plan

  variables {
    tier                                = "public"
    map_public_ip_on_launch             = true
    private_dns_hostname_type_on_launch = "resource-name"
  }

  assert {
    condition     = aws_subnet.this["az1"].map_public_ip_on_launch == true && aws_subnet.this["az1"].private_dns_hostname_type_on_launch == "resource-name" && aws_subnet.this["az1"].tags["Tier"] == "public"
    error_message = "Public tier settings must pass through."
  }
}

run "rejects_subnet_with_both_cidr_forms" {
  command = plan

  variables {
    availability_zones = {
      az1 = { availability_zone = "us-east-2a", cidr_block = "10.64.0.0/20", newbits = 4, netnum = 0 }
    }
  }

  expect_failures = [var.availability_zones]
}

run "rejects_subnet_without_any_cidr_form" {
  command = plan

  variables {
    availability_zones = {
      az1 = { availability_zone = "us-east-2a" }
    }
  }

  expect_failures = [var.availability_zones]
}

run "rejects_duplicate_availability_zone_in_a_tier" {
  command = plan

  variables {
    availability_zones = {
      az1 = { availability_zone = "us-east-2a", cidr_block = "10.64.0.0/20" }
      az2 = { availability_zone = "us-east-2a", cidr_block = "10.64.16.0/20" }
    }
  }

  expect_failures = [var.availability_zones]
}

run "rejects_derived_cidr_without_vpc_cidr" {
  command = plan

  variables {
    vpc_cidr_block = null
    availability_zones = {
      az1 = { availability_zone = "us-east-2a", newbits = 4, netnum = 0 }
    }
  }

  expect_failures = [aws_subnet.this]
}

run "rejects_unknown_route_table_mode" {
  command = plan

  variables {
    route_tables = "per_region"
  }

  expect_failures = [var.route_tables]
}

run "rejects_invalid_tier_name" {
  command = plan

  variables {
    tier = "Private Tier"
  }

  expect_failures = [var.tier]
}
