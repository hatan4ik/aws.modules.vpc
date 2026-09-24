provider "aws" {
  region = var.region
}

# Flow logs delivered to a log group the caller already owns, encrypted with a
# key the caller already owns. The module creates only the delivery role and
# the flow log, never touches the supplied group or key, and reports both
# through the same outputs a managed configuration would.
module "vpc" {
  source = "../../"

  name       = var.name
  cidr_block = var.cidr_block
  tags       = var.tags

  # Additional ranges associated with the VPC, for example 100.64.0.0/16 for
  # pod networking. The subnets below stay in the primary range.
  secondary_cidr_blocks = var.secondary_cidr_blocks

  subnets = {
    private = {
      availability_zones = {
        az1 = { availability_zone = var.availability_zones.az1, cidr_block = var.private_subnet_cidrs.az1 }
        az2 = { availability_zone = var.availability_zones.az2, cidr_block = var.private_subnet_cidrs.az2 }
      }
    }
  }

  flow_logs = {
    destination = {
      create_log_group = false
      log_group_arn    = var.flow_log_group_arn
      log_group_name   = var.flow_log_group_name
      kms_key_arn      = var.flow_log_kms_key_arn
    }
  }
}
