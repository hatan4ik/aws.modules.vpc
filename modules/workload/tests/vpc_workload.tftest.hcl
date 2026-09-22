mock_provider "aws" {}

variables {
  name                       = "test-workload-vpc"
  ipv4_ipam_pool_id          = "ipam-pool-0123abcd"
  ipv4_netmask_length        = 20
  flow_log_kms_key_arn       = "arn:aws:kms:us-east-2:111122223333:key/11111111-1111-1111-1111-111111111111"
  flow_log_retention_in_days = 30
  availability_zones = {
    use1-az1 = {
      availability_zone = "us-east-2a"
      subnet_newbits    = 2
      subnet_netnum     = 0
    }
    use1-az2 = {
      availability_zone = "us-east-2b"
      subnet_newbits    = 2
      subnet_netnum     = 1
    }
  }
  interface_endpoints = {
    sts = {
      service_name        = "com.amazonaws.us-east-2.sts"
      private_dns_enabled = true
    }
  }
  gateway_endpoints = {
    s3 = {
      service_name = "com.amazonaws.us-east-2.s3"
    }
  }
}

run "plans_private_ipam_vpc_with_two_azs" {
  command = plan

  assert {
    condition     = length(aws_subnet.private) == 2
    error_message = "The workload VPC must plan one private subnet per configured AZ."
  }

  assert {
    condition     = aws_vpc_encryption_control.this.mode == "enforce"
    error_message = "VPC encryption control must remain in enforce mode."
  }

  assert {
    condition     = length(aws_route_table_association.private) == length(var.availability_zones)
    error_message = "Every private subnet must have an explicit private route-table association."
  }
}

run "rejects_single_az" {
  command = plan

  variables {
    availability_zones = {
      use1-az1 = {
        availability_zone = "us-east-2a"
        subnet_newbits    = 2
        subnet_netnum     = 0
      }
    }
  }

  expect_failures = [var.availability_zones]
}
