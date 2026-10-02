# Interface endpoints share one security group that admits HTTPS from the VPC
# and nothing else; rules are standalone resources so ownership is unambiguous.
#
# The security group and its ingress rule are provisioned by the external
# aws.modules.security-group module rather than hand-rolled here (see its
# docs/CONSUMERS.md for the migration this call implements). The
# vpc_cidr_blocks-must-be-non-empty precondition that used to live on the
# inline aws_security_group resource has no equivalent in that module (it has
# no opinion on vpc_cidr_blocks, since that variable does not exist in its
# interface), so it is re-added below on a standalone terraform_data
# resource with unconditional count, not on aws_vpc_endpoint.interface: a
# precondition on a for_each resource never evaluates when that resource has
# zero instances (no interface_endpoints declared), which would have let
# this exact misconfiguration through silently. terraform_data.security_group_inputs
# always exists, so the check fires under every input combination, matching
# the original inline resource's guarantee exactly.

locals {
  security_group_name = coalesce(var.security_group_name, "${var.name}-interface-endpoints")

  # Keyed by position so an IPAM-allocated CIDR (unknown until apply) still
  # yields known instance keys, matching the security group module's own
  # ingress_rules map shape.
  https_ingress_rules = {
    for index, cidr in var.vpc_cidr_blocks : tostring(index) => {
      description = "HTTPS from the VPC"
      from_port   = 443
      to_port     = 443
      cidr_ipv4   = cidr
    } if var.create_security_group
  }

  # Branch on the known variable, not module.security_group.id's nullness:
  # that id is a genuinely unknown computed value under command = plan for a
  # not-yet-created group, and comparing an unknown value against null does
  # not evaluate at plan time even though the value can never actually be
  # null when var.create_security_group is true.
  security_group_ids = concat(
    var.create_security_group ? [module.security_group.id] : [],
    sort(tolist(var.security_group_ids)),
  )
}

module "security_group" {
  source = "git::https://github.com/hatan4ik/aws.modules.security-group.git?ref=a2142e9b7351c81735e4dbefdc7c66155dd4c266" # v1.1.0

  create        = var.create_security_group
  name          = local.security_group_name
  description   = var.security_group_description
  vpc_id        = var.vpc_id
  ingress_rules = local.https_ingress_rules
  tags          = var.tags
}

resource "terraform_data" "security_group_inputs" {
  input = { create_security_group = var.create_security_group, vpc_cidr_blocks = var.vpc_cidr_blocks }

  lifecycle {
    precondition {
      condition     = var.create_security_group ? length(var.vpc_cidr_blocks) > 0 : true
      error_message = "vpc_cidr_blocks must list at least one CIDR when create_security_group is true."
    }
  }
}

resource "aws_vpc_endpoint" "interface" {
  for_each = var.interface_endpoints

  vpc_id              = var.vpc_id
  vpc_endpoint_type   = "Interface"
  service_name        = each.value.service_name
  subnet_ids          = each.value.subnet_ids
  security_group_ids  = local.security_group_ids
  private_dns_enabled = each.value.private_dns_enabled
  policy              = each.value.policy_json
  ip_address_type     = each.value.ip_address_type

  dynamic "dns_options" {
    for_each = each.value.dns_record_ip_type == null && each.value.private_dns_only_for_inbound_resolver_endpoint == null ? [] : [each.value]

    content {
      dns_record_ip_type                             = dns_options.value.dns_record_ip_type
      private_dns_only_for_inbound_resolver_endpoint = dns_options.value.private_dns_only_for_inbound_resolver_endpoint
    }
  }

  tags = merge(var.tags, { Name = "${var.name}-${each.key}" })

  lifecycle {
    precondition {
      condition     = length(local.security_group_ids) > 0
      error_message = "Interface endpoints need at least one security group: keep create_security_group true or supply security_group_ids."
    }
  }
}

resource "aws_vpc_endpoint" "gateway" {
  for_each = var.gateway_endpoints

  vpc_id            = var.vpc_id
  vpc_endpoint_type = "Gateway"
  service_name      = each.value.service_name
  route_table_ids   = each.value.route_table_ids
  policy            = each.value.policy_json

  tags = merge(var.tags, { Name = "${var.name}-${each.key}" })
}

# 1.0.2 moved the group and its ingress rules under module.security_group
# without these blocks, so a consumer upgrading from 1.0.0 or 1.0.1 got a plan
# that destroyed the in-use group and created a same-named replacement (which
# EC2 rejects with InvalidGroup.Duplicate). These moves are relative to this
# module, so they apply at any depth (module.<vpc>.module.endpoints[0]...) and
# whether this repository and aws.modules.security-group are local or Git
# sources. Verified with terraform plan on 1.7.5 and 1.16.3 against state
# holding the 1.0.1 addresses: the group is moved with no change and each rule
# is moved with only its Name tag updated in place (<group>-https-<i> becomes
# <group>-<i>). Keep these blocks: removing them reintroduces the replacement
# for anyone still upgrading from 1.0.1 or earlier.
moved {
  from = aws_security_group.this[0]
  to   = module.security_group.aws_security_group.this[0]
}

moved {
  from = aws_vpc_security_group_ingress_rule.https
  to   = module.security_group.aws_vpc_security_group_ingress_rule.this
}
