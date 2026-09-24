# Upgrading from 0.x to 1.0.0

## What changed and why

Version 0.x carried two VPC implementations: the root (an explicit CIDR, private subnets only, a KMS key it always created, and partition, region, and account read from data sources) and `modules/workload` (an IPAM-allocated CIDR, a transit tier, Transit Gateway routes, endpoints, and a supplied key), with different names for the same things (`<name>-private-az1` versus `<name>-az1-private`), no way to express a public tier or NAT, and endpoints, flow logs, and routes welded into one file. Version 1.0.0 provisions one VPC per module call from one root that accepts `cidr_block` or `ipam`, declares subnet tiers as data, keeps internet access, endpoints, and flow logs as optional objects, composes five focused submodules (`subnets`, `routes`, `endpoints`, `flow-logs`, `internet`), takes partition, region, and account as inputs with a data-source fallback only where the flow-log key policy needs them, and keeps every v0.1.x name and tag so the live sandbox-network root migrates with `moved` blocks only. The reasons, and the table of 0.x behaviours that were replaced, are in [DESIGN.md](DESIGN.md). This guide gets an existing 0.x consumer onto 1.0.0 without recreating the VPC, subnets, route tables, KMS key, log group, or role.

## Input mapping

Root inputs of 0.1.1 through 0.3.0 (the root did not change after 0.1.1):

| 0.x root input | 1.0.0 equivalent |
| --- | --- |
| `name` | `name`, unchanged (same 3 to 51 character rule). |
| `vpc_cidr` | `cidr_block`. |
| `availability_zones` and `private_subnet_cidrs` | One map: `subnets.private.availability_zones = { <key> = { availability_zone = <zone>, cidr_block = <cidr> } }`, one entry per key. The "at least two Availability Zones" validation is now the advisory `single_az` check. |
| `flow_log_retention_in_days` | `flow_logs.retention_in_days` (default 365, same accepted values). |
| The root's own KMS key, always created | `flow_logs.destination.create_kms_key = true`. The 1.0.0 default is AWS-managed encryption with a warning, so set this explicitly to keep the key. |
| Partition, region, and account from data sources | `flow_logs.partition`, `flow_logs.region`, `flow_logs.account_id`. Optional: when omitted, the `flow-logs` submodule reads them from the provider exactly as the root did. Pass them to remove the reads. |
| `tags` | `tags`, unchanged. |

Inputs of `modules/workload` (0.1.0 through 0.3.0):

| `modules/workload` input | 1.0.0 equivalent |
| --- | --- |
| `name` | `name`. The root accepts 3 to 51 characters; the workload module accepted up to 63. |
| `ipv4_ipam_pool_id` and `ipv4_netmask_length` | `ipam = { pool_id = <pool>, netmask_length = <length> }`. `cidr_block` stays null. |
| `availability_zones = { <key> = { availability_zone, subnet_newbits, subnet_netnum } }` | `subnets.private.availability_zones = { <key> = { availability_zone, newbits, netnum } }`. Add `private_dns_hostname_type_on_launch = "resource-name"` to the tier to keep the workload setting; the 1.0.0 default leaves it unset. |
| `transit_gateway_attachment_subnets = { <key> = { subnet_newbits, subnet_netnum } }` | A `transit` tier: `subnets.transit = { availability_zones = { <key> = { availability_zone, newbits, netnum } }, private_dns_hostname_type_on_launch = "resource-name" }`, repeating the zone name from the private tier. Its keys no longer have to match the private tier's. |
| `transit_gateway_routes = { <key> = { destination_cidr_block, transit_gateway_id } }` | `subnets.private.routes = { <key> = { destination_cidr_block, transit_gateway_id } }`. Default destinations are still rejected because `allow_default_route` defaults to false. |
| `interface_endpoints = { <key> = { service_name, private_dns_enabled, policy_json } }` | `endpoints.interface = { <key> = { service_name, subnet_tier = "private", private_dns_enabled, policy_json } }`. `private_dns_enabled` is now optional and defaults to true. |
| `gateway_endpoints = { <key> = { service_name, policy_json } }` | `endpoints.gateway = { <key> = { service_name, route_table_tiers = ["private"], policy_json } }`. |
| `flow_log_kms_key_arn` | `flow_logs.destination.kms_key_arn`. |
| `flow_log_retention_in_days` | `flow_logs.retention_in_days`. |
| `tags` | `tags`. The PascalCase key validation is gone, and the module no longer adds `Component = "workload-vpc"`; put it in `tags` to keep it. |

Outputs:

| 0.x output | 1.0.0 equivalent |
| --- | --- |
| Root `vpc` (`id`, `arn`, `cidr`) | `vpc`, same shape. Also `vpc_id`, `vpc_arn`, `cidr_block`. |
| Root `private_subnets[<key>]` (`id`, `availability_zone`, `cidr`, `route_table_id`) | `private_subnets`, same shape. Also `subnets["private"][<key>]` (`id`, `arn`, `cidr_block`, `availability_zone`, `route_table_id`), `subnet_ids_by_tier["private"]`, `route_table_ids_by_tier["private"]`. |
| Root `flow_logs` (`id`, `log_group_name`, `kms_key_arn`, `role_arn`) | `flow_logs`, same shape. Also `flow_log_id`, `flow_log_group_name`, `flow_log_group_arn`, `flow_log_kms_key_arn`, `flow_log_role_arn`, `flow_log_role_name`. |
| Workload `vpc` (`id`, `arn`, `cidr_block`, `cidr`) | `vpc` (`id`, `arn`, `cidr`); `vpc.cidr_block` becomes `cidr_block`. |
| Workload `private_subnets[<key>]` (`id`, `cidr_block`, `route_table_id`, `az`, `availability_zone`) | `private_subnets[<key>]` (`cidr_block` becomes `cidr`, `az` becomes `availability_zone`) or `subnets["private"][<key>]` (keeps `cidr_block`). |
| Workload `transit_gateway_attachment_subnets[<key>]` | `subnets["transit"][<key>]`, `subnet_ids_by_tier["transit"]`, `route_table_ids_by_tier["transit"]`. |
| Workload `interface_endpoint_ids`, `gateway_endpoint_ids` | Same names. Also `gateway_endpoint_prefix_list_ids`. |
| Workload `interface_endpoint_security_group_id` | `endpoint_security_group_id`. |
| Workload `flow_log` and `flow_logs` (`id`, `log_group_arn`, `iam_role_arn`, `encryption_mode`) | `flow_logs` (`id`, `log_group_name`, `kms_key_arn`, `role_arn`), plus `flow_log_id`, `flow_log_group_arn`, `flow_log_role_arn`, and `encryption_control_mode`. |

## Preserving existing resources

The live sandbox-network root calls the 0.1.1 root with `name`, `vpc_cidr`, `availability_zones`, `private_subnet_cidrs`, `flow_log_retention_in_days`, and `tags`. This is its 1.0.0 call:

```hcl
module "sandbox_network" {
  source = "git::https://github.com/hatan4ik/aws.modules.vpc.git?ref=<commit-sha>" # v1.0.0

  name       = module.naming.name_prefix
  cidr_block = var.vpc_cidr
  tags       = module.naming.tags

  # Keep it off to leave the VPC untouched; enable later as a deliberate change.
  enable_network_address_usage_metrics = false

  subnets = {
    private = {
      availability_zones = {
        for key, zone in var.availability_zones : key => {
          availability_zone = zone
          cidr_block        = var.private_subnet_cidrs[key]
        }
      }
    }
  }

  flow_logs = {
    destination       = { create_kms_key = true }
    retention_in_days = var.flow_log_retention_in_days
    partition         = "aws"
    region            = var.aws_region
    account_id        = var.aws_account_id
  }
}
```

Every `Name` and `Tier` tag, the KMS key policy, the log group, the delivery role and its inline policy, and the flow log are identical to what the 0.1.1 root created: the VPC is `Name = <name>`; each subnet and route table is `<name>-private-<key>` with `Tier = private`; the default security group is `<name>-default-deny-all`; the key is `<name>-flow-logs` with `DataClass = network-observability`, alias `alias/<name>-flow-logs`, and the same two-statement policy; the log group is `/aws/vpc/<name>/flow-logs` with the same retention; the role is `<name>-vpc-flow-logs` with the inline policy `<name>-flow-logs-delivery`; the flow log is `<name>-all-traffic`. `aws_vpc_encryption_control` keeps `enforce` and the caller tags with no `Name`. With the `moved` blocks below, the plan shows moves only and the apply updates state only. The root's outputs `vpc`, `private_subnets`, and `flow_logs` keep their shape, so nothing downstream of the root changes.

Two details make the plan empty rather than nearly empty:

- `enable_network_address_usage_metrics = false`. The 1.0.0 default is `true`; the 0.1.x root never set it, so AWS reports `false`, and leaving the default would show one in-place update of `aws_vpc.this`. Keep it off during the migration and turn it on later as its own change.
- `partition`, `region`, and `account_id` are passed, so the three data sources the 0.1.x root read on every plan are not created under `module.flow_logs[0]`; they simply leave state.

For a `modules/workload` consumer, the equivalent call with the name-preserving settings (a block named `module.workload` with AZ keys `az1` and `az2`, one Transit Gateway route `hub`, and endpoints `ecr-api` and `s3`):

```hcl
module "workload" {
  source = "git::https://github.com/hatan4ik/aws.modules.vpc.git?ref=<commit-sha>" # v1.0.0

  name = var.name
  ipam = { pool_id = var.ipv4_ipam_pool_id, netmask_length = var.ipv4_netmask_length }
  tags = merge(var.tags, { Component = "workload-vpc" }) # only if you want to keep the tag the workload module added

  subnets = {
    private = {
      private_dns_hostname_type_on_launch = "resource-name"
      availability_zones = {
        az1 = { availability_zone = "us-east-2a", newbits = 4, netnum = 0 }
        az2 = { availability_zone = "us-east-2b", newbits = 4, netnum = 1 }
      }
      routes = {
        hub = { destination_cidr_block = "10.0.0.0/8", transit_gateway_id = var.transit_gateway_id }
      }
    }
    transit = {
      private_dns_hostname_type_on_launch = "resource-name"
      availability_zones = {
        # The last two /28s of a /20 allocation: keep the values your workload call used.
        az1 = { availability_zone = "us-east-2a", newbits = 8, netnum = 254 }
        az2 = { availability_zone = "us-east-2b", newbits = 8, netnum = 255 }
      }
    }
  }

  endpoints = {
    interface = {
      ecr-api = { service_name = "com.amazonaws.us-east-2.ecr.api", subnet_tier = "private" }
    }
    gateway = {
      s3 = { service_name = "com.amazonaws.us-east-2.s3", route_table_tiers = ["private"] }
    }
  }

  flow_logs = {
    destination       = { kms_key_arn = var.flow_log_kms_key_arn }
    retention_in_days = var.flow_log_retention_in_days
  }
}
```

The workload module was never applied from this repository, so its plan is not empty and does not need to be. What changes, all expected: `Name` tags on subnets and route tables (`<name>-az1-private` becomes `<name>-private-az1`, `<name>-az1-transit` becomes `<name>-transit-az1`), the default security group (`<name>-default-deny` becomes `<name>-default-deny-all`, and `revoke_rules_on_delete` is set), the log group's `Name` tag (the group name instead of the VPC name), the flow log's `Name` tag (`<name>-all-traffic`), the `Component` tag unless you keep it, tags added to `aws_vpc_encryption_control`, and a description on the delivery role, all in place. The inline role policy is replaced because its name changes from `<name>-vpc-flow-logs-write` to `<name>-flow-logs-delivery`; the role keeps its trust and the gap is momentary. The endpoint security group keeps its name and description and is updated in place, its inline rules become standalone resources, and `aws_vpc_security_group_ingress_rule.https["0"]` is created. If the group already carries the inline HTTPS rule in AWS, that create fails with `InvalidPermission.Duplicate`; import the existing rule by its `sgr-` ID into that address with an `import` block, or delete it from the group first.

## State moves

Old addresses are those of the 0.1.1 root under `module.sandbox_network` with AZ keys `az1` and `az2`. `aws_vpc.this` keeps its address. The three data sources (`data.aws_partition.current`, `data.aws_region.current`, `data.aws_caller_identity.current`) leave state; they touch nothing in AWS.

| 0.1.1 address | 1.0.0 address |
| --- | --- |
| `module.sandbox_network.aws_vpc.this` | Unchanged. |
| `module.sandbox_network.aws_default_security_group.deny_all` | `module.sandbox_network.aws_default_security_group.this` |
| `module.sandbox_network.aws_vpc_encryption_control.this` | `module.sandbox_network.aws_vpc_encryption_control.this[0]` |
| `module.sandbox_network.aws_subnet.private["az1"]` | `module.sandbox_network.module.subnets["private"].aws_subnet.this["az1"]` |
| `module.sandbox_network.aws_subnet.private["az2"]` | `module.sandbox_network.module.subnets["private"].aws_subnet.this["az2"]` |
| `module.sandbox_network.aws_route_table.private["az1"]` | `module.sandbox_network.module.subnets["private"].aws_route_table.this["az1"]` |
| `module.sandbox_network.aws_route_table.private["az2"]` | `module.sandbox_network.module.subnets["private"].aws_route_table.this["az2"]` |
| `module.sandbox_network.aws_route_table_association.private["az1"]` | `module.sandbox_network.module.subnets["private"].aws_route_table_association.this["az1"]` |
| `module.sandbox_network.aws_route_table_association.private["az2"]` | `module.sandbox_network.module.subnets["private"].aws_route_table_association.this["az2"]` |
| `module.sandbox_network.aws_kms_key.flow_logs` | `module.sandbox_network.module.flow_logs[0].aws_kms_key.this[0]` |
| `module.sandbox_network.aws_kms_alias.flow_logs` | `module.sandbox_network.module.flow_logs[0].aws_kms_alias.this[0]` |
| `module.sandbox_network.aws_cloudwatch_log_group.flow_logs` | `module.sandbox_network.module.flow_logs[0].aws_cloudwatch_log_group.this[0]` |
| `module.sandbox_network.aws_iam_role.flow_logs` | `module.sandbox_network.module.flow_logs[0].aws_iam_role.this[0]` |
| `module.sandbox_network.aws_iam_role_policy.flow_logs_delivery` | `module.sandbox_network.module.flow_logs[0].aws_iam_role_policy.this[0]` |
| `module.sandbox_network.aws_flow_log.vpc` | `module.sandbox_network.module.flow_logs[0].aws_flow_log.this` |
| `module.sandbox_network.data.aws_partition.current`, `data.aws_region.current`, `data.aws_caller_identity.current` | Not moved. Leave state. |

Ready to paste into the root configuration that contains `module "sandbox_network"`:

```hcl
moved {
  from = module.sandbox_network.aws_default_security_group.deny_all
  to   = module.sandbox_network.aws_default_security_group.this
}

moved {
  from = module.sandbox_network.aws_vpc_encryption_control.this
  to   = module.sandbox_network.aws_vpc_encryption_control.this[0]
}

moved {
  from = module.sandbox_network.aws_subnet.private["az1"]
  to   = module.sandbox_network.module.subnets["private"].aws_subnet.this["az1"]
}

moved {
  from = module.sandbox_network.aws_subnet.private["az2"]
  to   = module.sandbox_network.module.subnets["private"].aws_subnet.this["az2"]
}

moved {
  from = module.sandbox_network.aws_route_table.private["az1"]
  to   = module.sandbox_network.module.subnets["private"].aws_route_table.this["az1"]
}

moved {
  from = module.sandbox_network.aws_route_table.private["az2"]
  to   = module.sandbox_network.module.subnets["private"].aws_route_table.this["az2"]
}

moved {
  from = module.sandbox_network.aws_route_table_association.private["az1"]
  to   = module.sandbox_network.module.subnets["private"].aws_route_table_association.this["az1"]
}

moved {
  from = module.sandbox_network.aws_route_table_association.private["az2"]
  to   = module.sandbox_network.module.subnets["private"].aws_route_table_association.this["az2"]
}

moved {
  from = module.sandbox_network.aws_kms_key.flow_logs
  to   = module.sandbox_network.module.flow_logs[0].aws_kms_key.this[0]
}

moved {
  from = module.sandbox_network.aws_kms_alias.flow_logs
  to   = module.sandbox_network.module.flow_logs[0].aws_kms_alias.this[0]
}

moved {
  from = module.sandbox_network.aws_cloudwatch_log_group.flow_logs
  to   = module.sandbox_network.module.flow_logs[0].aws_cloudwatch_log_group.this[0]
}

moved {
  from = module.sandbox_network.aws_iam_role.flow_logs
  to   = module.sandbox_network.module.flow_logs[0].aws_iam_role.this[0]
}

moved {
  from = module.sandbox_network.aws_iam_role_policy.flow_logs_delivery
  to   = module.sandbox_network.module.flow_logs[0].aws_iam_role_policy.this[0]
}

moved {
  from = module.sandbox_network.aws_flow_log.vpc
  to   = module.sandbox_network.module.flow_logs[0].aws_flow_log.this
}
```

For a `modules/workload` consumer (block `module.workload`, AZ keys `az1` and `az2`, route key `hub`, endpoint keys `ecr-api` and `s3`) the analogous moves are:

| `modules/workload` address | 1.0.0 address |
| --- | --- |
| `module.workload.aws_vpc.this` | Unchanged. |
| `module.workload.aws_default_security_group.this` | Unchanged address; `Name` tag updated in place. |
| `module.workload.aws_vpc_encryption_control.this` | `module.workload.aws_vpc_encryption_control.this[0]` |
| `module.workload.aws_subnet.private["azN"]` | `module.workload.module.subnets["private"].aws_subnet.this["azN"]` |
| `module.workload.aws_route_table.private["azN"]` | `module.workload.module.subnets["private"].aws_route_table.this["azN"]` |
| `module.workload.aws_route_table_association.private["azN"]` | `module.workload.module.subnets["private"].aws_route_table_association.this["azN"]` |
| `module.workload.aws_subnet.transit_gateway_attachment["azN"]` | `module.workload.module.subnets["transit"].aws_subnet.this["azN"]` |
| `module.workload.aws_route_table.transit_gateway_attachment["azN"]` | `module.workload.module.subnets["transit"].aws_route_table.this["azN"]` |
| `module.workload.aws_route_table_association.transit_gateway_attachment["azN"]` | `module.workload.module.subnets["transit"].aws_route_table_association.this["azN"]` |
| `module.workload.aws_route.private_to_transit_gateway["azN:hub"]` | `module.workload.module.routes["private"].aws_route.this["azN/hub"]` (the key separator changes from `:` to `/`) |
| `module.workload.aws_security_group.interface_endpoints` | `module.workload.module.endpoints[0].aws_security_group.this[0]`; its inline rules become `aws_vpc_security_group_ingress_rule.https["0"]`, created (or imported, see above). |
| `module.workload.aws_vpc_endpoint.interface["ecr-api"]` | `module.workload.module.endpoints[0].aws_vpc_endpoint.interface["ecr-api"]` |
| `module.workload.aws_vpc_endpoint.gateway["s3"]` | `module.workload.module.endpoints[0].aws_vpc_endpoint.gateway["s3"]` |
| `module.workload.aws_cloudwatch_log_group.flow_logs` | `module.workload.module.flow_logs[0].aws_cloudwatch_log_group.this[0]` |
| `module.workload.aws_iam_role.flow_logs` | `module.workload.module.flow_logs[0].aws_iam_role.this[0]` |
| `module.workload.aws_iam_role_policy.flow_logs` | `module.workload.module.flow_logs[0].aws_iam_role_policy.this[0]` (then replaced: the policy name changes) |
| `module.workload.aws_flow_log.this` | `module.workload.module.flow_logs[0].aws_flow_log.this` |

```hcl
moved {
  from = module.workload.aws_vpc_encryption_control.this
  to   = module.workload.aws_vpc_encryption_control.this[0]
}

moved {
  from = module.workload.aws_subnet.private["az1"]
  to   = module.workload.module.subnets["private"].aws_subnet.this["az1"]
}

moved {
  from = module.workload.aws_subnet.private["az2"]
  to   = module.workload.module.subnets["private"].aws_subnet.this["az2"]
}

moved {
  from = module.workload.aws_route_table.private["az1"]
  to   = module.workload.module.subnets["private"].aws_route_table.this["az1"]
}

moved {
  from = module.workload.aws_route_table.private["az2"]
  to   = module.workload.module.subnets["private"].aws_route_table.this["az2"]
}

moved {
  from = module.workload.aws_route_table_association.private["az1"]
  to   = module.workload.module.subnets["private"].aws_route_table_association.this["az1"]
}

moved {
  from = module.workload.aws_route_table_association.private["az2"]
  to   = module.workload.module.subnets["private"].aws_route_table_association.this["az2"]
}

moved {
  from = module.workload.aws_subnet.transit_gateway_attachment["az1"]
  to   = module.workload.module.subnets["transit"].aws_subnet.this["az1"]
}

moved {
  from = module.workload.aws_subnet.transit_gateway_attachment["az2"]
  to   = module.workload.module.subnets["transit"].aws_subnet.this["az2"]
}

moved {
  from = module.workload.aws_route_table.transit_gateway_attachment["az1"]
  to   = module.workload.module.subnets["transit"].aws_route_table.this["az1"]
}

moved {
  from = module.workload.aws_route_table.transit_gateway_attachment["az2"]
  to   = module.workload.module.subnets["transit"].aws_route_table.this["az2"]
}

moved {
  from = module.workload.aws_route_table_association.transit_gateway_attachment["az1"]
  to   = module.workload.module.subnets["transit"].aws_route_table_association.this["az1"]
}

moved {
  from = module.workload.aws_route_table_association.transit_gateway_attachment["az2"]
  to   = module.workload.module.subnets["transit"].aws_route_table_association.this["az2"]
}

moved {
  from = module.workload.aws_route.private_to_transit_gateway["az1:hub"]
  to   = module.workload.module.routes["private"].aws_route.this["az1/hub"]
}

moved {
  from = module.workload.aws_route.private_to_transit_gateway["az2:hub"]
  to   = module.workload.module.routes["private"].aws_route.this["az2/hub"]
}

moved {
  from = module.workload.aws_security_group.interface_endpoints
  to   = module.workload.module.endpoints[0].aws_security_group.this[0]
}

moved {
  from = module.workload.aws_vpc_endpoint.interface["ecr-api"]
  to   = module.workload.module.endpoints[0].aws_vpc_endpoint.interface["ecr-api"]
}

moved {
  from = module.workload.aws_vpc_endpoint.gateway["s3"]
  to   = module.workload.module.endpoints[0].aws_vpc_endpoint.gateway["s3"]
}

moved {
  from = module.workload.aws_cloudwatch_log_group.flow_logs
  to   = module.workload.module.flow_logs[0].aws_cloudwatch_log_group.this[0]
}

moved {
  from = module.workload.aws_iam_role.flow_logs
  to   = module.workload.module.flow_logs[0].aws_iam_role.this[0]
}

moved {
  from = module.workload.aws_iam_role_policy.flow_logs
  to   = module.workload.module.flow_logs[0].aws_iam_role_policy.this[0]
}

moved {
  from = module.workload.aws_flow_log.this
  to   = module.workload.module.flow_logs[0].aws_flow_log.this
}
```

## Procedure

1. Pin the 1.0.0 release: copy the commit SHA of tag `v1.0.0` into `?ref=<commit-sha>` and put the tag in a trailing comment.
2. Rewrite the module block as shown above: `cidr_block` or `ipam`, the tiers under `subnets`, and `flow_logs` with `create_kms_key = true` (root consumers) or `kms_key_arn` (workload consumers). Keep `enable_network_address_usage_metrics = false` for the sandbox-network root, and pass `partition`, `region`, and `account_id`.
3. Add the `moved` blocks for every AZ key, route key, and endpoint key you have.
4. Run `terraform init -upgrade` to fetch the new module source, then `terraform plan`.
5. Verify the plan. There must be no replacement or destruction of `aws_vpc`, `aws_subnet`, `aws_route_table`, `aws_kms_key`, `aws_cloudwatch_log_group`, or `aws_iam_role`. For the sandbox-network root the plan is moves only: `Plan: 0 to add, 0 to change, 0 to destroy`, with every moved resource listed. For a workload consumer expect the in-place tag and attribute updates listed above, one `aws_iam_role_policy` replaced, and one `aws_vpc_security_group_ingress_rule` created or imported. If anything else shows `must be replaced`, compare its name, tags, or key with the tables above before applying.
6. Apply. For the sandbox-network root this updates state only; nothing in AWS changes.
7. Remove the `moved` blocks in a later change once every workspace that used 0.x has applied the upgrade.
