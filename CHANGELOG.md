# Changelog

All notable changes to this module are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html). Consumers pin the commit SHA of a release tag; see [Versioning and releases](README.md#versioning-and-releases).

## [Unreleased]

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
- Examples `minimal`, `private-endpoints-ipam`, `three-tier-nat`, `multiple-vpcs`, `ipam-hierarchy`, and `bring-your-own-flow-log-key`, validated in CI.
- Credential-driven integration suites `smoke` and `nat-egress` in `tests/integration/`, `make integration-smoke` and `make integration-nat-egress`, and the dispatch-only `integration` workflow that runs them through the protected `integration` environment.
- A Makefile-driven quality gate (`make check`: format, validate, lint, test, docs drift, Checkov and Trivy), the `module-release` workflow, and the standards files (`.editorconfig`, `.tflint.hcl`, `.terraform-docs.yml`, `.checkov.yml`, `trivy.yaml`, `.pre-commit-config.yaml`, `CODEOWNERS`, Dependabot, a pull request template).
- `docs/DESIGN.md`, `docs/UPGRADE-1.0.md`, submodule READMEs, `CONTRIBUTING.md`, `SECURITY.md`, and `LICENSE`.

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

[Unreleased]: https://github.com/hatan4ik/aws.modules.vpc/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/hatan4ik/aws.modules.vpc/compare/v0.3.0...v1.0.0
[0.3.0]: https://github.com/hatan4ik/aws.modules.vpc/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/hatan4ik/aws.modules.vpc/compare/v0.1.1...v0.2.0
[0.1.1]: https://github.com/hatan4ik/aws.modules.vpc/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/hatan4ik/aws.modules.vpc/releases/tag/v0.1.0
