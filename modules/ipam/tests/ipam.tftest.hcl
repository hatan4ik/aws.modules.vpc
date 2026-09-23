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
    condition     = length(aws_vpc_ipam_pool.regional) == 2 && aws_vpc_ipam_pool.regional["use2"].locale == "us-east-2"
    error_message = "The IPAM hierarchy must create one localized Regional pool per approved operating Region."
  }

  assert {
    condition     = length(aws_ram_resource_share.regional_pool) == 2 && length(aws_ram_principal_association.regional_pool) == 2
    error_message = "Each approved Regional pool must have only its reviewed RAM share and principals."
  }
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

run "rejects_pool_locales_outside_the_operating_regions" {
  command = plan

  variables {
    operating_regions = ["us-east-2"]
  }

  expect_failures = [terraform_data.configuration]
}
