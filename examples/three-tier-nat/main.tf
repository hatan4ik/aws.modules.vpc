provider "aws" {
  region = var.region
}

# Three tiers with an internet path: public subnets behind an internet
# gateway, private subnets that reach the internet outbound through a NAT
# gateway, and an isolated data tier with no routes beyond the VPC.
module "vpc" {
  source = "../../"

  name       = var.name
  cidr_block = var.cidr_block
  tags       = var.tags

  # Monitor mode reports unencrypted traffic between resources in the VPC
  # without blocking it; the default (enforce) blocks it.
  vpc_encryption_control = "monitor"

  subnets = {
    # /24 per AZ for load balancers and the NAT gateway. Instances launched
    # here still get no public IP unless map_public_ip_on_launch is set.
    public = {
      availability_zones = {
        az1 = { availability_zone = var.availability_zones.az1, newbits = 8, netnum = 0 }
        az2 = { availability_zone = var.availability_zones.az2, newbits = 8, netnum = 1 }
      }
      allow_default_route = true
      routes = {
        internet = { destination_cidr_block = "0.0.0.0/0", internet_gateway = true }
      }
    }

    # /20 per AZ for workloads. Every route table of a tier receives every
    # route, so one NAT gateway serves both AZs; see the README for the
    # one-tier-per-AZ layout that gives each AZ its own NAT gateway.
    private = {
      availability_zones = {
        az1 = { availability_zone = var.availability_zones.az1, newbits = 4, netnum = 1 }
        az2 = { availability_zone = var.availability_zones.az2, newbits = 4, netnum = 2 }
      }
      allow_default_route = true
      routes = {
        internet = { destination_cidr_block = "0.0.0.0/0", nat_gateway_key = "az1" }
      }
    }

    # /22 per AZ for databases: no routes, so nothing outside the VPC is
    # reachable and default routes are rejected at plan time.
    data = {
      availability_zones = {
        az1 = { availability_zone = var.availability_zones.az1, newbits = 6, netnum = 12 }
        az2 = { availability_zone = var.availability_zones.az2, newbits = 6, netnum = 13 }
      }
    }
  }

  # Declaring internet creates the internet gateway; each NAT gateway names
  # its subnet as <tier>/<az key> and gets a module-created Elastic IP.
  internet = {
    nat_gateways = {
      az1 = { subnet = "public/az1" }
    }
  }

  flow_logs = {
    destination = { create_kms_key = true }
  }
}
