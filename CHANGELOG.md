# Changelog

All notable changes to this module are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html). Consumers pin the commit SHA of a release tag; see [Versioning and releases](README.md#versioning-and-releases).

## [Unreleased]

## [1.1.0] - 2026-10-02

Fixes the 1.0.2 upgrade path and a flow-logs plan crash. Two behaviour changes are called out below: a gateway-only `endpoints` configuration no longer creates a security group, and three flow-log key combinations that were previously accepted are now rejected at plan time.

### Upgrade notes

- **From 1.0.0 or 1.0.1 with interface endpoints:** upgrade directly to 1.1.0. The `moved` blocks in `modules/endpoints/main.tf` move the existing group and rules to their 1.0.2 addresses, so the plan shows `aws_security_group.this[0] has moved to module.security_group.aws_security_group.this[0]` with no change and one in-place `Name` tag update per ingress rule (`<group>-https-<i>` to `<group>-<i>`). Nothing is destroyed. Verified with `terraform plan` on Terraform 1.7.5 and 1.16.3 against state holding the 1.0.1 addresses, with both this repository and `aws.modules.security-group` as Git sources, both through the root (`module.<vpc>.module.endpoints[0]`) and with `modules/endpoints` called directly. No `terraform state mv` is needed.
- **From 1.0.2:** nothing to do; the `moved` blocks are no-ops when the old addresses are not in state.
- **Gateway-only `endpoints` (no `endpoints.interface`):** the plan destroys the unused `<name>-interface-endpoints` group and its rules. Set `endpoints.create_security_group = true` to keep it.
- **`flow_logs.destination`:** a plan that previously succeeded fails if it sets `create_kms_key = true` or `kms_key_arn` with `type = "s3"`, or `create_kms_key = true` with `create_log_group = false`. Remove the setting: it never encrypted anything in those combinations (for `create_kms_key = true` with an existing log group, removing it destroys the unused key and alias, which enter their deletion window).

### Added

- Advisory check `nat_gateway_tier_without_internet_route`: warns when a public NAT gateway sits in a tier that has no `0.0.0.0/0` route through `internet_gateway = true`, which plans cleanly but leaves the NAT gateway with no path to the internet.
- `modules/endpoints`: `moved` blocks from the 1.0.1 addresses of the security group and its ingress rules to their `module.security_group` addresses.
- README: a Quotas section listing the AWS service quotas the module's designs run into (Elastic IPs per Region, NAT gateways per Availability Zone, interface endpoints per VPC, gateway endpoints per Region, IPv4 CIDR blocks per VPC, routes per route table).

### Changed

- **Behaviour change:** `modules/endpoints` `create_security_group` defaults to `null`, which creates the group only when `interface_endpoints` is non-empty; the root's `endpoints.create_security_group` is `optional(bool)` and passes through. Gateway endpoints take no security group, so a gateway-only configuration no longer creates an unused group. Configurations with interface endpoints, and any explicit `true` or `false`, are unaffected.
- **Behaviour change:** `modules/flow-logs` rejects, through `destination` validation, `create_kms_key = true` or a `kms_key_arn` with `type = "s3"` (they apply only to a CloudWatch log group), and `create_kms_key = true` with `create_log_group = false` (the key and alias were created and billed but encrypted nothing).
- `modules/flow-logs`: the key policy's CloudWatch Logs service principal is `logs.<region>.<partition DNS suffix>`, so it is `logs.<region>.amazonaws.com.cn` in `aws-cn` (and the matching suffix in the other non-commercial partitions). Unchanged in `aws` and `aws-us-gov`.
- The default endpoint security-group description is declared once, as the `modules/endpoints` `security_group_description` default. The root passes `endpoints.security_group_description` through as given and a null selects that default, instead of repeating the literal in a `coalesce`. The rendered description is unchanged.
- The CI quality workflow uses `terraform-pipelines` v0.1.1 (`8fc2a04`), matching the release workflow; v0.1.0 to v0.1.1 changes only that repository's `module-release.yml` and self-test.

### Deprecated

- `modules/ipam-organization-admin` `tags`. Neither of its resources (`aws_ram_sharing_with_organization`, `aws_vpc_ipam_organization_admin_account`) has a `tags` argument, so the input cannot be wired to anything and has never had an effect. It will be removed in 2.0.0; removing it now would break callers that pass it. The `ipam-hierarchy` example no longer passes it.

### Fixed

- `modules/flow-logs`: `destination = { type = "s3", s3_bucket_arn = ..., create_kms_key = true }` passed validation and then failed at plan with `Invalid index` on `aws_kms_key.this[0]` and `aws_kms_alias.this[0]`. It is now a validation error, and the key's `count`, the `kms_key_arn` local, and the `kms_key_alias_arn` output share one condition.
- `modules/internet` and `modules/ipam` no longer use `try()` (in `aws_nat_gateway.this` `allocation_id` and the `regional_pools` output), matching the no-`try()` claim in the 1.0.0 entry; the values are identical.
- Documentation: `modules/subnets` `subnet_cidr_blocks` no longer claims CIDRs are always known at plan time; the `modules/endpoints` README describes the precondition on `terraform_data.security_group_inputs` and the current rule names; the root README naming table, lifecycle notes, and check list match the code; the 1.0.2 entry below no longer claims the ingress rules' tags are unchanged; the 1.0.1 entry is added and the items first released in 1.0.1 are moved out of the 1.0.0 entry.

## [1.0.2] - 2026-09-29

> **Known issue, fixed in 1.1.0:** this release moved the endpoint security group and its ingress rules to new resource addresses without `moved` blocks. Upgrading to 1.0.2 from 1.0.0 or 1.0.1 with interface endpoints plans to destroy the in-use group and create a same-named replacement, which EC2 rejects with `InvalidGroup.Duplicate`. Upgrade straight to 1.1.0 instead, which carries the `moved` blocks; do not apply a 1.0.2 plan that destroys `module.endpoints[0].aws_security_group.this[0]`.

### Changed

- `modules/endpoints` now provisions its interface-endpoint security group and HTTPS ingress rule through the external `aws.modules.security-group` module instead of hand-rolling them, ending an independent copy of the same primitive also used by `aws.modules.ecs-service` and (from its own next release) `aws.modules.alb`. The security group's name, description, and tags, and each ingress rule's content, are unchanged. Two things did change: the resource addresses (`aws_security_group.this[0]` became `module.security_group.aws_security_group.this[0]`, and `aws_vpc_security_group_ingress_rule.https["<i>"]` became `module.security_group.aws_vpc_security_group_ingress_rule.this["<i>"]`), and each ingress rule's `Name` tag, from `<group name>-https-<i>` to `<group name>-<i>` (an in-place tag update). This release shipped no `moved` blocks for the address change; see the known issue above. The `vpc_cidr_blocks`-must-be-non-empty validation moved from the inline security group to a standalone `terraform_data.security_group_inputs` resource so it keeps firing under every input combination, including when no `interface_endpoints` are declared.

## [1.0.1] - 2026-09-25

No change to any resource the root or the `subnets`, `routes`, `endpoints`, `flow-logs`, or `internet` submodules create.

### Added

- `modules/ipam`: a `partition` input for the RAM permission ARN; the `aws_partition` data source is now only a fallback when it is null.
- Examples `minimal`, `private-endpoints-ipam`, `three-tier-nat`, `multiple-vpcs`, `ipam-hierarchy`, and `bring-your-own-flow-log-key`, validated in CI.
- Credential-driven integration suites `smoke` and `nat-egress` in `tests/integration/`, `make integration-smoke` and `make integration-nat-egress`, and the dispatch-only `integration` workflow that runs them through the protected `integration` environment.
- A Makefile-driven quality gate (`make check`: format, validate, lint, test, docs drift, Checkov and Trivy), the `module-release` workflow, the quality workflow on the shared `terraform-pipelines` reusable workflow, and the standards files (`.editorconfig`, `.tflint.hcl`, `.terraform-docs.yml`, `.checkov.yml`, `trivy.yaml`, `.pre-commit-config.yaml`, `CODEOWNERS`, Dependabot, issue and pull request templates).
- `docs/UPGRADE-1.0.md`, READMEs for the `subnets`, `routes`, `endpoints`, `flow-logs`, and `internet` submodules, this changelog, `CONTRIBUTING.md`, `SECURITY.md`, and `LICENSE`.

### Changed

- `modules/ipam`: the `home_region`/`operating_regions` and pool-locale cross-checks are preconditions on `aws_vpc_ipam.this` instead of a separate `terraform_data.configuration` resource, which the first 1.0.1 plan destroys (it holds no infrastructure).
- `modules/ipam-organization-admin`: the `tags` description now states that the value has no effect.

## [1.0.0] - 2026-09-24

Breaking release. One module call now provisions one VPC of any shape, and `modules/workload` is folded into the root. [docs/UPGRADE-1.0.md](docs/UPGRADE-1.0.md) maps every root and `modules/workload` input and output to its replacement, gives the exact 1.0.0 call for the live sandbox-network root, and provides ready-to-paste `moved` blocks that keep every existing resource.

### Added

- Submodules `subnets`, `routes`, `endpoints`, `flow-logs`, and `internet`, each with its own contract tests and README, usable standalone from a Git source against a VPC created elsewhere.
- `subnets`: tiers as data. Any number of tiers keyed by the `Tier` tag value, each with subnets keyed by a stable AZ key, an explicit `cidr_block` or `newbits`/`netnum` against the VPC CIDR, `route_tables = "per_az"` or `"shared"`, `map_public_ip_on_launch`, `private_dns_hostname_type_on_launch`, `allow_default_route`, and `routes`.
- Routes with every AWS target: `transit_gateway_id`, `nat_gateway_id`, `gateway_id`, `egress_only_gateway_id`, `vpc_peering_connection_id`, `network_interface_id`, `vpc_endpoint_id`, `core_network_arn`, `carrier_gateway_id`, `local_gateway_id`, and destinations by CIDR, IPv6 CIDR, or prefix list. References to gateways the root creates (`nat_gateway_key`, `internet_gateway = true`, `egress_only_internet_gateway = true`) are resolved to IDs by the root.
- `internet`: an internet gateway, an egress-only internet gateway, and NAT gateways (public with created or supplied Elastic IPs, or private) placed by `<tier>/<az_key>`. Off unless declared.
- `endpoints`: interface endpoints placed by `subnet_tier`, gateway endpoints associated by `route_table_tiers`, endpoint policies, `ip_address_type` and DNS options, a created HTTPS-only security group with standalone rules or caller-supplied `security_group_ids`, and `security_group_name`/`security_group_description`.
- `flow_logs`: a CloudWatch destination with a created key (`create_kms_key`), a supplied key (`kms_key_arn`), or AWS-managed encryption; an existing log group (`create_log_group = false` with `log_group_arn`); `log_group_name` and `log_group_class`; an S3 destination (`type = "s3"`, `s3_bucket_arn`, `s3_options`); `traffic_type`, `max_aggregation_interval`, `log_format`; role name, path, and permissions boundary; `kms_key_deletion_window_in_days`; and `partition`, `region`, `account_id` inputs. `flow_logs = null` disables flow logs.
- Root inputs `ipam` (a VPC IPAM pool and netmask, replacing `cidr_block`), `secondary_cidr_blocks`, `instance_tenancy`, `enable_dns_support`, `enable_dns_hostnames`, `enable_network_address_usage_metrics`, and `vpc_encryption_control` (`enforce`, `monitor`, or `null`).
- Advisory `check` blocks that warn without blocking: `single_az`, `flow_logs_disabled`, `flow_logs_without_customer_key`, `internet_path_declared`.
- Plan-time validation of every input and cross-reference: exactly one of `cidr_block` or `ipam`; tier, AZ, route, endpoint, and NAT gateway keys; one Availability Zone per subnet within a tier; exactly one CIDR form per subnet; exactly one destination and one target per route; the default-route guard; endpoint targets with CIDR destinations only; NAT subnet references and `nat_gateway_key` values against what `internet` declares; gateway references against `create_internet_gateway` and `create_egress_only_internet_gateway`; endpoint tiers against declared tiers; flow-log destination combinations; retention values of at least 365 days.
- Flat outputs for every identifier: `vpc_id`, `vpc_arn`, `cidr_block`, `secondary_cidr_blocks`, `default_security_group_id`, `encryption_control_mode`, `subnets`, `subnet_ids_by_tier`, `subnet_cidr_blocks_by_tier`, `route_table_ids_by_tier`, `internet_gateway_id`, `egress_only_internet_gateway_id`, `nat_gateway_ids`, `nat_gateway_public_ips`, `interface_endpoint_ids`, `gateway_endpoint_ids`, `gateway_endpoint_prefix_list_ids`, `endpoint_security_group_id`, `flow_log_id`, `flow_log_group_name`, `flow_log_group_arn`, `flow_log_kms_key_arn`, `flow_log_role_arn`, `flow_log_role_name`, plus the compatibility outputs `vpc`, `private_subnets`, and `flow_logs` in the 0.1.x root's shape.

- `docs/DESIGN.md`.

### Changed

- **Breaking:** the root provisions any VPC shape from `subnets`, `internet`, `endpoints`, and `flow_logs` objects instead of a fixed private-only layout. Root inputs are renamed: `vpc_cidr` to `cidr_block`; `availability_zones` and `private_subnet_cidrs` to `subnets.private.availability_zones`; `flow_log_retention_in_days` to `flow_logs.retention_in_days`.
- **Breaking:** the flow-log KMS key is no longer created unconditionally. Set `flow_logs.destination.create_kms_key = true` to keep it, or `kms_key_arn` to supply one; the default is AWS-managed encryption with the `flow_logs_without_customer_key` warning.
- **Breaking:** `aws_default_security_group.deny_all` is `aws_default_security_group.this`, and `aws_vpc_encryption_control.this` is `aws_vpc_encryption_control.this[0]`. Subnets, route tables, associations, and every flow-log resource live under `module.subnets["<tier>"]` and `module.flow_logs[0]`. The upgrade guide lists the `moved` blocks.
- **Breaking:** the "at least two Availability Zones" validation is the advisory `single_az` check; a tier with one subnet is accepted with a warning.
- **Breaking, former `modules/workload` consumers:** subnet and route-table names are `<name>-<tier>-<az_key>` (were `<name>-<az_key>-<tier>`); the default security group is `<name>-default-deny-all` (was `<name>-default-deny`) with `revoke_rules_on_delete`; the flow log is named `<name>-all-traffic` and the log group's `Name` is its own name (both were the VPC name); the delivery role's inline policy is `<name>-flow-logs-delivery` (was `<name>-vpc-flow-logs-write`); the `Component = "workload-vpc"` tag and the PascalCase tag-key validation are gone; `name` is 3 to 51 characters (was 3 to 63); `private_dns_hostname_type_on_launch` is unset unless the tier sets it (was `resource-name`); the transit tier no longer has to share the private tier's keys; route resources are keyed `<az_key>/<route_key>` (were `<az_key>:<route_key>`).
- Partition, region, and account are inputs. The only data-source reads left are the fallbacks in `flow-logs`, and only for the inputs not given.
- The interface-endpoint security group's rules are standalone `aws_vpc_security_group_ingress_rule` resources keyed by position, one per VPC CIDR including secondary CIDRs (were inline rules on the group).
- Cross-input rules are preconditions on the resources they guard (`aws_vpc.this`, `aws_subnet.this`, `aws_route.this`, `aws_nat_gateway.this`, `aws_security_group.this`, `aws_vpc_endpoint.interface`) with typed inputs and no `try()` in resource arguments.
- The module adds only `Name` (and `Tier` on subnets and route tables) to each resource. Caller tags pass through unchanged.

### Removed

- **Breaking:** `modules/workload` and its inputs `ipv4_ipam_pool_id`, `ipv4_netmask_length`, `availability_zones` (with `subnet_newbits`/`subnet_netnum`), `transit_gateway_attachment_subnets`, `transit_gateway_routes`, `interface_endpoints`, `gateway_endpoints`, `flow_log_kms_key_arn`, `flow_log_retention_in_days`, and its outputs `transit_gateway_attachment_subnets`, `interface_endpoint_security_group_id`, and `flow_log`. Every capability is in the root; the upgrade guide maps each input.
- **Breaking:** root inputs `vpc_cidr`, `availability_zones`, `private_subnet_cidrs`, and `flow_log_retention_in_days`.
- The root's `aws_partition`, `aws_region`, and `aws_caller_identity` data sources.
- `tests/sandbox_network.tftest.hcl` and `modules/workload/tests`, replaced by `tests/defaults.tftest.hcl` (the same sandbox inputs in 1.0.0 form), `tests/composition.tftest.hcl`, `tests/validation.tftest.hcl`, and one test file per submodule.

### Fixed

- Two VPC implementations drifted in names, tags, and behaviour (`<name>-private-az1` versus `<name>-az1-private`, `-default-deny-all` versus `-default-deny`, a created versus a required key). One implementation now produces one contract.
- The `modules/workload` flow log did not depend on the delivery role policy, so the first delivery attempt could precede the permission. The flow log now depends on the policy in every mode.

## [0.3.0] - 2026-09-23

### Added

- `modules/ipam` and `modules/ipam-organization-admin`: organization-managed VPC IPAM with a delegated administrator, a top-level pool, and regional pools that VPCs allocate from (#2).

## [0.2.0] - 2026-09-23

### Added

- `modules/workload`: `transit_gateway_attachment_subnets` for a dedicated `Tier = transit` subnet tier keyed by the private tier's AZ keys, and `transit_gateway_routes` for explicit non-default routes from every private route table to an approved Transit Gateway; output `transit_gateway_attachment_subnets` (#1).
- The quality workflow tests reusable modules that declare `configuration_aliases` with the provider alias supplied by their test file.

## [0.1.1] - 2026-09-22

### Changed

- The root and `modules/workload` READMEs carry the generated terraform-docs reference.

## [0.1.0] - 2026-09-22

### Added

- The sandbox network root: a private-only VPC from an explicit CIDR with AZ-keyed private subnets and empty route tables, a deny-all default security group, VPC Encryption Control in `enforce` mode, and VPC Flow Logs to a CloudWatch log group encrypted with a dedicated customer-managed KMS key; outputs `vpc`, `private_subnets`, and `flow_logs`.
- `modules/workload`: an IPAM-allocated private VPC with `subnet_newbits`/`subnet_netnum` subnets, interface and gateway endpoints behind an HTTPS-only security group, and flow logs encrypted with a supplied key.

[Unreleased]: https://github.com/hatan4ik/aws.modules.vpc/compare/v1.1.0...HEAD
[1.1.0]: https://github.com/hatan4ik/aws.modules.vpc/compare/v1.0.2...v1.1.0
[1.0.2]: https://github.com/hatan4ik/aws.modules.vpc/compare/v1.0.1...v1.0.2
[1.0.1]: https://github.com/hatan4ik/aws.modules.vpc/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/hatan4ik/aws.modules.vpc/compare/v0.3.0...v1.0.0
[0.3.0]: https://github.com/hatan4ik/aws.modules.vpc/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/hatan4ik/aws.modules.vpc/compare/v0.1.1...v0.2.0
[0.1.1]: https://github.com/hatan4ik/aws.modules.vpc/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/hatan4ik/aws.modules.vpc/releases/tag/v0.1.0
