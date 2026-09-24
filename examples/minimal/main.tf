provider "aws" {
  region = var.region
}

# The sandbox pattern: one VPC with a single private tier across two
# Availability Zones and nothing else. No internet gateway, NAT gateway, or
# endpoint exists until it is declared, the default security group is managed
# deny-all, VPC Encryption Control is enforced, and flow logs are on.
module "vpc" {
  source = "../../"

  name       = var.name
  cidr_block = var.cidr_block
  tags       = var.tags

  subnets = {
    private = {
      availability_zones = {
        az1 = { availability_zone = var.availability_zones.az1, cidr_block = var.private_subnet_cidrs.az1 }
        az2 = { availability_zone = var.availability_zones.az2, cidr_block = var.private_subnet_cidrs.az2 }
      }
    }
  }

  # Flow logs go to CloudWatch Logs by default. Creating a customer-managed key
  # here encrypts the log group with it instead of AWS-managed encryption.
  flow_logs = {
    destination = { create_kms_key = true }
  }
}
