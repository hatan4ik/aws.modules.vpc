provider "aws" {
  region = var.region
}

# One module call is one VPC. A fleet is a for_each over the module block, so
# each VPC keeps its own plan, its own validation errors, and its own
# lifecycle, and adding or removing a VPC is adding or removing a map entry.
module "vpc" {
  source   = "../../"
  for_each = var.vpcs

  name       = "${var.name_prefix}-${each.key}"
  cidr_block = each.value.cidr_block
  subnets    = each.value.subnets
  tags       = merge(var.tags, { Network = each.key })

  # Each VPC gets its own flow-log key and log group.
  flow_logs = {
    destination = { create_kms_key = true }
  }
}
