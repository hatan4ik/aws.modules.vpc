# Disposable inputs for the integration suites: two Availability Zone names
# and the region resolved from the caller's credentials, and a unique VPC
# name. The module under test creates every network resource itself, so the
# only fixture resource is the random suffix; `terraform test` resolves this
# in the caller's own account before the module is applied.

data "aws_availability_zones" "available" {
  state = "available"

  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

data "aws_region" "current" {}

resource "random_id" "suffix" {
  byte_length = 3
}

locals {
  name               = "${var.name_prefix}-${random_id.suffix.hex}"
  availability_zones = slice(data.aws_availability_zones.available.names, 0, 2)

  tags = merge(var.tags, {
    IntegrationTest = "aws.modules.vpc"
    Disposable      = "true"
  })
}
