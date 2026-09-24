# Design: aws.modules.vpc v1

Status: accepted 2026-09-24. Supersedes the v0.x "sandbox network module" root and the `modules/workload` submodule.

## Purpose

`aws.modules.vpc` provisions **one** Amazon VPC per module call together with what a VPC cannot be used without: subnet tiers with their route tables and routes, the locked-down default security group, VPC Flow Logs, and, when asked for, VPC endpoints and internet access (internet gateway and NAT gateways). It is secure by default, explicit by declaration, and composable: each concern is a focused submodule that can be used on its own.

The module deliberately does **not** create Transit Gateway attachments, peering connections, DNS zones, or workloads. Those are separate concerns with separate owners; the module consumes or exposes their identifiers.

## Why the v0.x design was replaced

| v0.x behaviour | Problem | v1 decision |
|---|---|---|
| Two VPC implementations: the root (direct CIDR, private-only, its own KMS key) and `modules/workload` (IPAM CIDR, transit tier, endpoints, BYO key). | Duplicate resources with drifting names (`<name>-private-az1` vs `<name>-az1-private`), two upgrade paths, two test suites. | One root that accepts `cidr_block` or `ipam`, with subnet tiers as data. |
| Private subnets only; no public tier, internet gateway, or NAT. | Cannot express the most common VPC shapes. | Optional `internet` (IGW, egress-only IGW, NAT gateways) and public tiers, all off by default. |
| Endpoints, flow logs, and routes welded into one file. | No single responsibility; not reusable against an existing VPC. | `subnets`, `routes`, `endpoints`, `flow-logs`, `internet` submodules. |
| Partition, region, and account from data sources. | Hidden API reads on every plan. | Inputs with a data-source fallback only in `flow-logs`, where the KMS policy needs the log-group ARN before the group exists. |
| `terraform_data` precondition carriers, `try()` in resource arguments, inline security-group rules. | Weak plan-time errors; mixed rule ownership. | Preconditions on the guarded resources, typed inputs, standalone rules. |
| No examples, thin tests, release workflow pinned to a shared workflow that cannot publish. | Not consumable as a product. | Examples, contract and integration tests, standards, working release. |

## Principles applied

- **Single responsibility.** `subnets` owns subnet and route-table shape; `routes` owns route entries; `endpoints` owns PrivateLink and gateway endpoints; `flow-logs` owns log delivery; `internet` owns internet and NAT gateways. The root owns the VPC, its CIDR associations, encryption control, and the default security group, and composes the rest.
- **Open/closed.** New shapes are declared as data: another tier, another route, another endpoint, another NAT gateway. Names, tags, and boundaries are inputs.
- **Liskov substitution.** Every submodule works against a caller-supplied VPC or route tables; caller-supplied KMS keys, log groups, and security groups are drop-ins for managed ones.
- **Interface segregation.** `internet`, `endpoints`, and `flow_logs` are optional objects; a private VPC needs `name`, a CIDR, and one tier.
- **Dependency inversion.** The root depends on identifiers, never on how upstream resources were produced.

## Architecture

```text
root (one VPC)
├── aws_vpc.this                          cidr_block | ipam; DNS; NAU metrics
├── aws_vpc_ipv4_cidr_block_association   secondary CIDRs
├── aws_vpc_encryption_control.this       enforce | monitor | off
├── aws_default_security_group.this       always managed, deny-all
├── modules/subnets  (one per tier)       subnets, route tables (per AZ or shared), associations
├── modules/internet (optional)           internet gateway, egress-only gateway, NAT gateways + EIPs
├── modules/routes   (one per tier)       routes into the tier's route tables; targets resolved by the root
├── modules/endpoints (optional)          interface + gateway endpoints, endpoint security group
└── modules/flow-logs (optional)          CloudWatch (KMS: created or supplied) or S3 destination, delivery role
modules/ipam, modules/ipam-organization-admin   organisation-level IPAM (unchanged responsibilities)
```

Data flow: tiers are created first; the internet module consumes public-tier subnet IDs for NAT gateways; the root resolves route targets (`internet_gateway`, `nat_gateway_key`, `egress_only_internet_gateway`, or explicit IDs) and hands IDs to the routes module; endpoints consume tier subnet and route-table IDs; flow logs consume only the VPC ID. Routes are a separate module precisely so that a private tier's route through a NAT gateway in the public tier does not create a dependency cycle between tier instances.

## Naming and tag contract

The platform roots discover the network by tags, so these are stable: the VPC carries `Name = <name>`; every subnet and route table carries `Name = <name>-<tier>-<az_key>` (or `<name>-<tier>` for a shared table) and `Tier = <tier>`; the default security group is `<name>-default-deny-all`; the flow log is `<name>-all-traffic`; the created flow-log KMS key is `<name>-flow-logs` with `DataClass = network-observability`; the log group is `/aws/vpc/<name>/flow-logs`; the delivery role is `<name>-vpc-flow-logs`. These match the v0.1.x root exactly, so the live sandbox-network root migrates with `moved` blocks and a no-change plan.

## Security defaults

No internet gateway, NAT, or public subnet unless declared; default security group emptied and managed; VPC encryption control enforced; flow logs on for all traffic with 60-second aggregation and one-year minimum retention; endpoint security group allows HTTPS from the VPC only; default routes rejected unless a tier opts in; every route names exactly one destination and one target.

## Testing strategy

Contract tests with `mock_provider` at the root and in every submodule; integration suites `smoke` (private VPC, gateway endpoint, flow logs with a created key) and `nat-egress` (public and private tiers, IGW, one NAT gateway) applied in the caller's own account; examples validated in CI; tflint, Checkov, Trivy, and docs drift in the quality matrix.

## Compatibility and migration

Terraform `>= 1.7.0, < 2.0.0`, AWS provider `>= 6.35.0, < 7.0.0`. `docs/UPGRADE-1.0.md` maps every root and `modules/workload` input, gives the exact v1 call for the live sandbox-network root, and the `moved` blocks that keep every existing resource. IPv6, network ACLs, DHCP option sets, and VPC Lattice are roadmap items that will be added as optional inputs.
