mock_provider "aws" {
  mock_data "aws_partition" {
    defaults = {
      partition = "aws"
    }
  }
}

variables {
  name              = "platform-ipam"
  home_region       = "us-east-2"
  operating_regions = ["us-east-2", "us-west-2"]
  top_level_cidr    = "10.128.0.0/9"
  tags              = { Owner = "network" }
  regional_pools = {
    use2 = {
      locale                            = "us-east-2"
      cidr                              = "10.128.0.0/16"
      allocation_default_netmask_length = 20
      allocation_min_netmask_length     = 20
      allocation_max_netmask_length     = 24
      ram_principals                    = ["111122223333"]
    }
    usw2 = {
      locale                            = "us-west-2"
      cidr                              = "10.129.0.0/16"
      allocation_default_netmask_length = 20
      allocation_min_netmask_length     = 20
      allocation_max_netmask_length     = 24
      ram_principals                    = ["444455556666"]
    }
  }
}

run "plans_regional_pools_and_account_scoped_ram_shares" {
  command = plan

  assert {
    condition     = aws_vpc_ipam.this.tier == "advanced" && length(aws_vpc_ipam.this.operating_regions) == 2 && aws_vpc_ipam.this.tags["Name"] == "platform-ipam" && aws_vpc_ipam.this.tags["Component"] == "network-ipam" && aws_vpc_ipam.this.tags["Owner"] == "network"
    error_message = "The IPAM must be advanced-tier, operate in every declared Region, and carry the computed and caller tags."
  }

  assert {
    condition     = aws_vpc_ipam_pool_cidr.top_level.cidr == "10.128.0.0/9" && aws_vpc_ipam_pool.top_level.tags["Name"] == "platform-ipam-private" && aws_vpc_ipam_pool.top_level.tags["Scope"] == "enterprise"
    error_message = "The top-level pool must reserve the enterprise CIDR without a locale."
  }

  assert {
    condition     = length(aws_vpc_ipam_pool.regional) == 2 && aws_vpc_ipam_pool.regional["use2"].locale == "us-east-2" && aws_vpc_ipam_pool.regional["use2"].allocation_default_netmask_length == 20 && aws_vpc_ipam_pool.regional["use2"].allocation_max_netmask_length == 24 && aws_vpc_ipam_pool_cidr.regional["usw2"].cidr == "10.129.0.0/16"
    error_message = "The IPAM hierarchy must create one localized Regional pool per approved operating Region with its netmask policy and CIDR."
  }

  assert {
    condition     = aws_vpc_ipam_pool.regional["use2"].tags["Name"] == "platform-ipam-use2" && aws_vpc_ipam_pool.regional["use2"].tags["Locale"] == "us-east-2" && aws_vpc_ipam_pool.regional["use2"].tags["Scope"] == "regional"
    error_message = "Regional pools must be tagged with their key, locale, and scope."
  }

  assert {
    condition     = length(aws_ram_resource_share.regional_pool) == 2 && length(aws_ram_resource_association.regional_pool) == 2 && length(aws_ram_principal_association.regional_pool) == 2
    error_message = "Each approved Regional pool must have only its reviewed RAM share and principals."
  }

  assert {
    condition     = aws_ram_resource_share.regional_pool["use2"].name == "platform-ipam-use2-ipam-pool" && aws_ram_resource_share.regional_pool["use2"].allow_external_principals == false && contains(aws_ram_resource_share.regional_pool["use2"].permission_arns, "arn:aws:ram::aws:permission/AWSRAMDefaultPermissionsIpamPool")
    error_message = "Pool shares must use the AWS-managed IPAM pool permission and never allow external principals."
  }

  assert {
    condition     = aws_ram_principal_association.regional_pool["use2:111122223333"].principal == "111122223333" && aws_ram_principal_association.regional_pool["usw2:444455556666"].principal == "444455556666"
    error_message = "Principal associations must be keyed by pool and principal."
  }

  assert {
    condition     = output.ipam.home_region == "us-east-2" && output.regional_pools["use2"].locale == "us-east-2" && output.regional_pools["use2"].cidr == "10.128.0.0/16" && length(output.regional_pools) == 2
    error_message = "Outputs must expose the home Region and every Regional pool with its locale and CIDR."
  }
}

run "shares_nothing_without_ram_principals" {
  command = plan

  variables {
    operating_regions = ["us-east-2"]
    regional_pools = {
      use2 = {
        locale                            = "us-east-2"
        cidr                              = "10.128.0.0/16"
        allocation_default_netmask_length = 20
      }
    }
  }

  assert {
    condition     = length(aws_ram_resource_share.regional_pool) == 0 && length(aws_ram_resource_association.regional_pool) == 0 && length(aws_ram_principal_association.regional_pool) == 0
    error_message = "A pool without ram_principals must not be shared."
  }

  assert {
    condition     = output.regional_pools["use2"].ram_resource_share_arn == null
    error_message = "An unshared pool must report a null share ARN."
  }
}

run "accepts_organization_and_ou_principals" {
  command = plan

  variables {
    operating_regions = ["us-east-2"]
    regional_pools = {
      use2 = {
        locale                            = "us-east-2"
        cidr                              = "10.128.0.0/16"
        allocation_default_netmask_length = 20
        ram_principals = [
          "arn:aws:organizations::111122223333:organization/o-abc123def4",
          "arn:aws:organizations::111122223333:ou/o-abc123def4/ou-root-abcd1234",
        ]
      }
    }
  }

  assert {
    condition     = length(aws_ram_resource_share.regional_pool) == 1 && length(aws_ram_principal_association.regional_pool) == 2
    error_message = "Organization and OU ARNs must each become a principal association on the pool's single share."
  }
}

run "uses_the_partition_input_without_a_lookup" {
  command = plan

  variables {
    partition = "aws-us-gov"
  }

  assert {
    condition     = length(data.aws_partition.current) == 0 && contains(aws_ram_resource_share.regional_pool["use2"].permission_arns, "arn:aws-us-gov:ram::aws:permission/AWSRAMDefaultPermissionsIpamPool")
    error_message = "A declared partition must skip the data source and shape the permission ARN."
  }
}

run "rejects_invalid_name" {
  command = plan

  variables {
    name = "Platform_IPAM"
  }

  expect_failures = [var.name]
}

run "rejects_invalid_home_region" {
  command = plan

  variables {
    home_region = "us-east"
  }

  expect_failures = [var.home_region]
}

run "rejects_empty_operating_regions" {
  command = plan

  variables {
    operating_regions = []
  }

  expect_failures = [var.operating_regions]
}

run "rejects_invalid_operating_region" {
  command = plan

  variables {
    operating_regions = ["us-east-2", "us-west-2", "eu"]
  }

  expect_failures = [var.operating_regions]
}

run "rejects_ipv6_top_level_cidr" {
  command = plan

  variables {
    top_level_cidr = "fd00::/8"
  }

  expect_failures = [var.top_level_cidr]
}

run "rejects_malformed_top_level_cidr" {
  command = plan

  variables {
    top_level_cidr = "10.128.0.0/33"
  }

  expect_failures = [var.top_level_cidr]
}

run "rejects_empty_regional_pools" {
  command = plan

  variables {
    regional_pools = {}
  }

  expect_failures = [var.regional_pools]
}

run "rejects_two_pools_in_one_locale" {
  command = plan

  variables {
    regional_pools = {
      use2 = {
        locale                            = "us-east-2"
        cidr                              = "10.128.0.0/16"
        allocation_default_netmask_length = 20
      }
      use2-b = {
        locale                            = "us-east-2"
        cidr                              = "10.129.0.0/16"
        allocation_default_netmask_length = 20
      }
    }
  }

  expect_failures = [var.regional_pools]
}

run "rejects_default_netmask_outside_16_to_28" {
  command = plan

  variables {
    regional_pools = {
      use2 = {
        locale                            = "us-east-2"
        cidr                              = "10.128.0.0/16"
        allocation_default_netmask_length = 30
      }
    }
  }

  expect_failures = [var.regional_pools]
}

run "rejects_min_netmask_longer_than_default" {
  command = plan

  variables {
    regional_pools = {
      use2 = {
        locale                            = "us-east-2"
        cidr                              = "10.128.0.0/16"
        allocation_default_netmask_length = 20
        allocation_min_netmask_length     = 24
      }
    }
  }

  expect_failures = [var.regional_pools]
}

run "rejects_ipv6_pool_cidr" {
  command = plan

  variables {
    regional_pools = {
      use2 = {
        locale                            = "us-east-2"
        cidr                              = "fd00:1::/48"
        allocation_default_netmask_length = 20
      }
    }
  }

  expect_failures = [var.regional_pools]
}

run "rejects_iam_ram_principals" {
  command = plan

  variables {
    regional_pools = {
      use2 = {
        locale                            = "us-east-2"
        cidr                              = "10.128.0.0/16"
        allocation_default_netmask_length = 20
        ram_principals                    = ["arn:aws:iam::111122223333:role/invalid"]
      }
    }
  }

  expect_failures = [var.regional_pools]
}

run "rejects_invalid_partition" {
  command = plan

  variables {
    partition = "AWS"
  }

  expect_failures = [var.partition]
}

run "rejects_home_region_outside_the_operating_regions" {
  command = plan

  variables {
    operating_regions = ["us-west-2"]
    regional_pools = {
      usw2 = {
        locale                            = "us-west-2"
        cidr                              = "10.129.0.0/16"
        allocation_default_netmask_length = 20
      }
    }
  }

  expect_failures = [aws_vpc_ipam.this]
}

run "rejects_pool_locales_outside_the_operating_regions" {
  command = plan

  variables {
    operating_regions = ["us-east-2"]
  }

  expect_failures = [aws_vpc_ipam.this]
}
