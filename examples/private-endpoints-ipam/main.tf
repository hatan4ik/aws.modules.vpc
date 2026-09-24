provider "aws" {
  region = var.region
}

# The workload pattern: the primary CIDR is allocated from an IPAM pool,
# workloads live in a private tier that reaches the rest of the network through
# a Transit Gateway, a small transit tier holds the attachment, and AWS APIs are
# reached through VPC endpoints instead of an internet path.
module "vpc" {
  source = "../../"

  name = var.name
  tags = var.tags

  # The CIDR is known only after apply, so every subnet is carved from it with
  # newbits and netnum instead of a literal cidr_block.
  ipam = {
    pool_id        = var.ipam_pool_id
    netmask_length = var.ipam_netmask_length
  }

  subnets = {
    # The first two quarters of the allocation, one route table per AZ, and a
    # route to the hub network through the Transit Gateway.
    private = {
      availability_zones = {
        az1 = { availability_zone = var.availability_zones.az1, newbits = 2, netnum = 0 }
        az2 = { availability_zone = var.availability_zones.az2, newbits = 2, netnum = 1 }
      }
      routes = {
        hub = { destination_cidr_block = var.hub_cidr_block, transit_gateway_id = var.transit_gateway_id }
      }
    }

    # Transit Gateway attachment subnets: two 1/64 slices at the top of the
    # allocation that share one route table.
    transit = {
      availability_zones = {
        az1 = { availability_zone = var.availability_zones.az1, newbits = 6, netnum = 60 }
        az2 = { availability_zone = var.availability_zones.az2, newbits = 6, netnum = 61 }
      }
      route_tables = "shared"
    }
  }

  # Interface endpoints sit in the private subnets behind a module-created
  # security group that admits HTTPS from the VPC and nothing else. The S3
  # gateway endpoint is associated with the route tables of both tiers.
  endpoints = {
    interface = {
      ecr-api = { service_name = "com.amazonaws.${var.region}.ecr.api", subnet_tier = "private" }
      ecr-dkr = { service_name = "com.amazonaws.${var.region}.ecr.dkr", subnet_tier = "private" }
      logs    = { service_name = "com.amazonaws.${var.region}.logs", subnet_tier = "private" }
      sts     = { service_name = "com.amazonaws.${var.region}.sts", subnet_tier = "private" }
    }
    gateway = {
      s3 = { service_name = "com.amazonaws.${var.region}.s3", route_table_tiers = ["private", "transit"] }
    }
  }

  # The log group is encrypted with a key the platform already owns.
  flow_logs = {
    destination = { kms_key_arn = var.flow_log_kms_key_arn }
  }
}
