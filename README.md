# aws.modules.vpc

Provisions **one** Amazon VPC per module call together with what a VPC cannot be used without: subnet tiers with their route tables and routes, a managed deny-all default security group, VPC Encryption Control, and VPC Flow Logs. Internet access (internet gateway, egress-only gateway, NAT gateways) and VPC endpoints are created only when declared. The primary CIDR is either explicit or allocated from a VPC IPAM pool. Every concern is a focused submodule (`subnets`, `routes`, `endpoints`, `flow-logs`, `internet`) that can be used on its own against a VPC created elsewhere. It is secure by default, explicit by declaration, and creates nothing beyond the network primitives it owns. Requires Terraform >= 1.7 and the AWS provider >= 6.35, < 7.

## Why this module

What you get from `name`, a CIDR, and one tier, without setting anything else:

- No internet path. `internet` defaults to `null`, so there is no internet gateway, no NAT gateway, and no public subnet; every tier has `map_public_ip_on_launch = false` unless it says otherwise.
- A managed deny-all default security group. The VPC's default group is always brought under management as `<name>-default-deny-all` with no ingress, no egress, and `revoke_rules_on_delete`, so workloads must use purpose-specific groups.
- VPC Encryption Control in `enforce` mode. `monitor` is available; `null` leaves it unmanaged.
- Flow logs for all traffic, on by default: 60-second aggregation, a CloudWatch log group `/aws/vpc/<name>/flow-logs` with 365-day retention (the minimum the module accepts), and a delivery role scoped to that one log group. A customer-managed key is one line away (`flow_logs.destination.create_kms_key = true` or `kms_key_arn`), and an advisory check warns while the log group uses AWS-managed encryption.
- One route table per subnet (`route_tables = "per_az"`), so a route change or a table problem is contained to one Availability Zone. `shared` is a per-tier choice.
- Default routes rejected. `0.0.0.0/0` and `::/0` destinations fail the plan unless the tier sets `allow_default_route = true`, so a private tier cannot be given an internet path by accident.
- Every route names exactly one destination (`destination_cidr_block`, `destination_ipv6_cidr_block`, or `destination_prefix_list_id`) and exactly one target. Targets may be IDs or references to gateways this module creates (`nat_gateway_key`, `internet_gateway = true`, `egress_only_internet_gateway = true`), and the root resolves those references before the routes module sees them.
- An endpoint security group that admits HTTPS from the VPC CIDRs and nothing else, with standalone rule resources, created only when `endpoints` is set.
- DNS support and hostnames on, Network Address Usage metrics on.
- Stable names and tags. The VPC is `Name = <name>`; every subnet and route table is `Name = <name>-<tier>-<az_key>` with `Tier = <tier>`; the platform roots discover the network by exactly these tags (see [Naming and tag contract](#naming-and-tag-contract)).
- Plan-time validation of every input and cross-reference: exactly one of `cidr_block` or `ipam`, CIDR syntax, tier and AZ keys, one AZ per subnet within a tier, `newbits`/`netnum` against the VPC CIDR, NAT gateway subnet references (`<tier>/<az_key>`), `nat_gateway_key` and gateway references against what `internet` creates, endpoint tiers against declared tiers, flow-log destinations, retention values, and the route rules above.
- No data-source reads, with one documented exception: `flow-logs` resolves partition, region, and account from the provider only when you do not pass them, because its KMS key policy must name the log-group ARN before the group exists.
- Only `Name` (and `Tier` on subnets and route tables) is added to each resource. Caller tags are never overridden.

## Quick start

```hcl
module "network" {
  source = "git::https://github.com/hatan4ik/aws.modules.vpc.git?ref=<commit-sha>" # v1.0.0

  name       = "orders-network"
  cidr_block = "10.0.0.0/16"

  subnets = {
    private = {
      availability_zones = {
        az1 = { availability_zone = "us-east-2a", cidr_block = "10.0.0.0/20" }
        az2 = { availability_zone = "us-east-2b", cidr_block = "10.0.16.0/20" }
      }
    }
  }

  flow_logs = {
    destination = { create_kms_key = true }
  }

  tags = { Environment = "prod", Owner = "platform" }
}
```

This creates a VPC `orders-network` at `10.0.0.0/16` with DNS enabled and encryption control enforced, the deny-all default security group `orders-network-default-deny-all`, two private subnets `orders-network-private-az1` and `orders-network-private-az2` tagged `Tier = private`, each with its own empty route table of the same name, and a flow log `orders-network-all-traffic` capturing all traffic to `/aws/vpc/orders-network/flow-logs` (365-day retention) encrypted with a new rotated KMS key `alias/orders-network-flow-logs` whose policy admits only the CloudWatch Logs service for that log group, delivered through the role `orders-network-vpc-flow-logs`. No internet gateway, NAT gateway, public subnet, or endpoint exists. Pass `flow_logs.partition`, `region`, and `account_id` to avoid the three data-source reads the key policy otherwise needs.

## Architecture

```text
root (one VPC)
├── vpc.tf              aws_vpc.this (cidr_block | ipam), aws_vpc_ipv4_cidr_block_association.this[*],
│                       aws_vpc_encryption_control.this[0], aws_default_security_group.this (deny-all)
├── locals.tf           NAT subnet references and route targets (nat_gateway_key, internet_gateway,
│                       egress_only_internet_gateway) resolved to IDs; plan-time reference sets
├── checks.tf           single_az, flow_logs_disabled, flow_logs_without_customer_key, internet_path_declared
├── modules/subnets     one instance per tier: subnets, route tables (per_az | shared), associations
├── modules/internet    [0] when internet is set: internet gateway, egress-only gateway, NAT gateways + EIPs
├── modules/routes      one instance per tier: every route installed into every route table of the tier
├── modules/endpoints   [0] when endpoints is set: interface + gateway endpoints, endpoint security group
└── modules/flow-logs   [0] when flow_logs is set: CloudWatch (created or supplied key and log group) or S3, delivery role
modules/ipam, modules/ipam-organization-admin   organisation-level IPAM, documented in their own READMEs
```

Tiers are created first. The internet module consumes public-tier subnet IDs for NAT gateways. The root resolves route targets that name gateways it creates and hands plain IDs to one routes instance per tier. Endpoints consume the subnet IDs of `subnet_tier` and the route-table IDs of `route_table_tiers`. Flow logs consume only the VPC ID. Routes live in their own module, not in `subnets`, so a private tier's route through a NAT gateway that sits in the public tier does not create a dependency cycle between tier instances.

| Concern | Managed by default | Bring your own |
| --- | --- | --- |
| Flow-log KMS key | None: the log group uses AWS-managed encryption and the `flow_logs_without_customer_key` check warns on every plan. | `flow_logs.destination.kms_key_arn` for an existing key, or `flow_logs.destination.create_kms_key = true` for a rotated key `<name>-flow-logs` whose policy admits the CloudWatch Logs service for this log group only. The two are mutually exclusive. |
| Flow-log log group | `/aws/vpc/<name>/flow-logs`, `retention_in_days = 365`, `STANDARD` class, role `<name>-vpc-flow-logs` with an inline policy scoped to `<log-group-arn>:*`. | `flow_logs.destination.create_log_group = false` with `log_group_arn`; the role is scoped to that ARN. Or `flow_logs.destination.type = "s3"` with `s3_bucket_arn` and `s3_options`: no log group, no role. `flow_logs = null` disables flow logs and the `flow_logs_disabled` check warns. |
| Endpoint security group | `<name>-interface-endpoints` with one HTTPS ingress rule per VPC CIDR (primary and secondary) and no egress, attached to every interface endpoint. | `endpoints.create_security_group = false` with at least one ID in `endpoints.security_group_ids`. `security_group_ids` also adds groups alongside the managed one. |
| Internet access | None. No internet gateway, egress-only gateway, NAT gateway, or Elastic IP. | `internet = {}` creates an internet gateway; `internet.nat_gateways` adds NAT gateways in `<tier>/<az_key>` subnets with a created Elastic IP each, or `allocation_id` for one you own, or `connectivity_type = "private"` for no public address; `create_egress_only_internet_gateway = true` for IPv6 egress. Gateways created elsewhere are routed to by ID (`gateway_id`, `nat_gateway_id`, `egress_only_gateway_id`). |
| Addressing | `cidr_block`, explicit subnet CIDRs. | `ipam = { pool_id, netmask_length }` allocates the primary CIDR from a VPC IPAM pool and subnets derive theirs with `newbits` and `netnum`; `secondary_cidr_blocks` associates more IPv4 ranges. |

## Usage patterns

| Example | What it shows |
| --- | --- |
| [`examples/minimal`](examples/minimal) | The sandbox pattern: an explicit CIDR, one private tier across two Availability Zones with empty route tables, flow logs with a created key. |
| [`examples/private-endpoints-ipam`](examples/private-endpoints-ipam) | The workload pattern: IPAM-allocated CIDR with `newbits`/`netnum` subnets, a dedicated `transit` tier with a shared route table, Transit Gateway routes on the private tier, interface and gateway endpoints, a supplied flow-log key. |
| [`examples/three-tier-nat`](examples/three-tier-nat) | Public, private, and data tiers, an internet gateway, NAT gateways in the public tier, default routes through `internet_gateway = true` and `nat_gateway_key`, `allow_default_route` on the tiers that need it. |
| [`examples/multiple-vpcs`](examples/multiple-vpcs) | `for_each` over a map of VPC definitions: one module call per VPC sharing tags and a flow-log key. |
| [`examples/ipam-hierarchy`](examples/ipam-hierarchy) | `modules/ipam-organization-admin` and `modules/ipam` building the pool hierarchy whose leaf pool feeds `ipam.pool_id`. |
| [`examples/bring-your-own-flow-log-key`](examples/bring-your-own-flow-log-key) | `flow_logs.destination.kms_key_arn` with a key you manage, and the key policy statement that key needs. |

## Security model

Network

- There is no internet path unless declared. `internet` is `null` by default; a route with `internet_gateway = true`, `egress_only_internet_gateway = true`, or `nat_gateway_key` fails the plan unless `internet` creates the gateway it names, and a public NAT gateway fails unless the internet gateway exists. The `internet_path_declared` check warns on every plan of a VPC that has an internet gateway or NAT gateways, so the choice is visible in every review.
- Default routes are guarded. A precondition on every `aws_route` rejects `0.0.0.0/0` and `::/0` unless the tier sets `allow_default_route = true`. Tiers that may reach the internet declare it; every other tier cannot.
- The default security group is always managed as deny-all (`<name>-default-deny-all`, empty ingress and egress, rules revoked on delete). Nothing is placed in it by the module and nothing should be.
- Subnets do not assign public IPv4 addresses unless the tier sets `map_public_ip_on_launch = true`.

Encryption

- VPC Encryption Control is `enforce` by default, so traffic between resources in the VPC must be encrypted in transit. `monitor` reports without enforcing; `null` creates no `aws_vpc_encryption_control` resource. The resource carries the caller tags and no `Name`, exactly as the v0.1.x root created it.

Flow logs and retention

- Flow logs are on by default for `ALL` traffic at 60-second aggregation. Retention accepts only CloudWatch Logs values of 365 days or more (365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653); network evidence is kept for at least a year.
- The delivery role trusts `vpc-flow-logs.amazonaws.com` only and its inline policy grants `logs:CreateLogStream`, `logs:DescribeLogStreams`, and `logs:PutLogEvents` on `<log-group-arn>:*`, nothing else. Name, path, and permissions boundary are inputs. An S3 destination needs no role and creates none.
- A created key is rotated, has a 30-day deletion window (7 to 30), and its policy has two statements: account-root administration and the CloudWatch Logs service principal of the region, conditioned on `kms:EncryptionContext:aws:logs:arn` equal to this log group's ARN. The key is tagged `DataClass = network-observability`. A supplied key is used as-is; its policy must admit the same service principal.
- The `flow_logs_disabled` and `flow_logs_without_customer_key` checks warn, on every plan, when flow logs are off or the log group uses AWS-managed encryption.

Endpoints

- Interface endpoints share one security group, `<name>-interface-endpoints`, with one `aws_vpc_security_group_ingress_rule` per VPC CIDR for TCP 443 and no egress rules. Rules are standalone resources, so ownership is unambiguous. An interface endpoint with no security group at all is rejected at plan time.
- Service names are passed in full (`com.amazonaws.<region>.<service>` or `aws.<service>`); the module never infers a region. `private_dns_enabled` defaults to `true`. Endpoint policies are opaque JSON you own.

Not created here

- Transit Gateway attachments, VPC peering connections, DNS zones and resolver rules, network ACLs, DHCP option sets, and workloads. They have separate lifecycles and owners. The module consumes their identifiers (`transit_gateway_id`, `vpc_peering_connection_id`, and the other route targets) and exposes its own (`vpc_id`, `subnet_ids_by_tier`, `route_table_ids_by_tier`, endpoint IDs, gateway IDs).

## Naming and tag contract

The platform roots discover the network by tags, so these are stable across releases, exactly as [docs/DESIGN.md](docs/DESIGN.md) states:

| Resource | `Name` | Other tags |
| --- | --- | --- |
| VPC | `<name>` | |
| Subnet | `<name>-<tier>-<az_key>` | `Tier = <tier>` |
| Route table | `<name>-<tier>-<az_key>` (`per_az`) or `<name>-<tier>` (`shared`) | `Tier = <tier>` |
| Default security group | `<name>-default-deny-all` | |
| Flow log | `<name>-all-traffic` | |
| Created flow-log KMS key | `<name>-flow-logs`, alias `alias/<name>-flow-logs` | `DataClass = network-observability` |
| Flow-log log group | `/aws/vpc/<name>/flow-logs` (also its name) | |
| Flow-log delivery role | `<name>-vpc-flow-logs` (name; inline policy `<name>-flow-logs-delivery`) | |
| Internet gateway, egress-only gateway | `<name>-igw`, `<name>-eigw` | |
| NAT gateway and its Elastic IP | `<name>-nat-<key>` | |
| Endpoint | `<name>-<key>` | |
| Endpoint security group and its rules | `<name>-interface-endpoints`, `<name>-interface-endpoints-https-<index>` | |

Tier keys are the `Tier` values (`private`, `transit`, `public`, `data`, or any `^[a-z][a-z0-9-]{0,30}$`; lowercase and hyphens only because they become a tag), and the platform roots select subnets and route tables by `tag:Tier` and the VPC by `tag:Name`. AZ keys (`az1`, `az2`, or any 1 to 32 characters of letters, digits, underscores, and hyphens) are stable identifiers, not Availability Zone names, so a subnet keeps its name and address if you move it between zones. NAT gateway keys follow the same rule; route and endpoint keys allow 1 to 63 characters and dots as well. Every key is part of a resource address and, for subnets, route tables, NAT gateways, and endpoints, of the `Name` tag. Caller tags are merged first and never overridden; the module adds only the tags in this table.

## Lifecycle notes

- Routes are a separate module for a reason. A tier's route through a NAT gateway in another tier would make the `subnets` instances depend on each other through the internet module, and Terraform cannot order that. `subnets` owns tables, `routes` owns entries, and the root resolves targets in between. Every route is installed into every route table of its tier as `aws_route.this["<route table key>/<route key>"]`, so a `per_az` tier gets identical routing in each Availability Zone; a tier whose zones must route differently (each through its own NAT gateway, for example) is declared as one tier per zone.
- `route_tables` is a per-tier choice with consequences. `per_az` creates `aws_route_table.this["<az_key>"]` for each subnet; `shared` creates `aws_route_table.this["shared"]` named `<name>-<tier>`. Switching an existing tier replaces its tables, associations, routes, and gateway-endpoint associations, because the table keys change. Decide when the tier is created, or use `moved` blocks for the table you keep.
- Renaming a tier key or an AZ key replaces the resources under it. Keys are addresses; change the `availability_zone` or `cidr_block` values instead when you mean to move or resize.
- IPAM CIDRs are unknown until apply. With `ipam`, `aws_vpc.this.cidr_block`, the subnet CIDRs derived with `newbits`/`netnum`, and outputs `cidr_block` and `subnet_cidr_blocks_by_tier` are known only after the first apply, so nothing in the module keys a resource on them: the endpoint security group's rules are keyed by position (`https["0"]`, `https["1"]`), not by CIDR. Explicit `cidr_block` values are known at plan time, and mixing forms within a tier is allowed.
- Four `check` blocks warn on every plan and apply but never block: `single_az` (a tier with one subnet), `flow_logs_disabled` (`flow_logs = null`), `flow_logs_without_customer_key` (a created CloudWatch log group with no `kms_key_arn` and no `create_kms_key`), and `internet_path_declared` (`internet` is set). They name situations that are valid but usually unintended; a test expects each to fire.
- `endpoints.security_group_description` is immutable on the group. Changing it replaces the group and re-attaches every interface endpoint. `security_group_name` is likewise replace-on-change.
- Secondary CIDRs are keyed by their value (`aws_vpc_ipv4_cidr_block_association.this["10.1.0.0/16"]`) and appear in the endpoint security group's HTTPS rules automatically. Subnets in a secondary range use explicit `cidr_block`; `newbits`/`netnum` derive from the primary CIDR only.
- Public NAT gateways depend on the internet gateway, and their created Elastic IPs are released with them. Destroying `internet` while private routes still name `nat_gateway_key` fails at plan time; remove the routes first.
- Flow-log delivery starts after the role policy exists (`depends_on`), so the first records are never lost to a missing permission.
- `enable_network_address_usage_metrics` defaults to `true`. A VPC created by the v0.1.x root never set it, so AWS reports `false` and the first v1 plan shows one in-place update of `aws_vpc.this`. Set it to `false` to leave the VPC untouched during migration and enable it later as a deliberate change; [docs/UPGRADE-1.0.md](docs/UPGRADE-1.0.md) does exactly that.

## Testing

Two layers, deliberately separate:

- **Contract tests** (`tests/` for the root and `modules/*/tests/` for each submodule, run by `make test` and by CI) use `mock_provider`: no credentials, nothing created, placeholder IDs and the AWS documentation account `123456789012`. `tests/defaults.tftest.hcl` pins the live sandbox-network root's inputs in v1 form and asserts every platform name and tag; `tests/composition.tftest.hcl` pins the full composition (three tiers, NAT, Transit Gateway route, endpoints) and the target resolution; `tests/validation.tftest.hcl` covers every precondition and validation through `expect_failures`. The `flow-logs` tests supply `mock_data` for the three fallback data sources and assert the constructed key policy and role policy.
- **Integration suites** (`tests/integration/`, run by `make integration-smoke` and `make integration-nat-egress`, or the dispatch-only `integration` workflow) apply the module for real in **your** account with **your** credentials and region from the environment, then destroy everything. `smoke` creates a private VPC with a gateway endpoint and flow logs with a created key, at no charge. `nat-egress` creates public and private tiers, an internet gateway, and one NAT gateway with a default route through it, which costs a few cents for the NAT gateway hour and its Elastic IP. The owner lane runs the same suites from GitHub Actions through the protected `integration` environment, which holds the OIDC role and region; see [`tests/integration`](tests/integration) for permissions and the environment contract.

## Design principles

- Single responsibility. `subnets` owns subnet and route-table shape; `routes` owns route entries; `endpoints` owns PrivateLink and gateway endpoints and their security group; `flow-logs` owns log delivery, its key, log group, and role; `internet` owns the internet, egress-only, and NAT gateways with their Elastic IPs. The root owns the VPC, its CIDR associations, encryption control, and the default security group, and composes the rest.
- Open/closed. New shapes are declared as data: another tier in `subnets`, another route in a tier's `routes`, another endpoint in `endpoints.interface` or `gateway`, another NAT gateway in `internet.nat_gateways`, another CIDR in `secondary_cidr_blocks`. Names, descriptions, paths, and boundaries are inputs; no shape needs the module edited.
- Liskov substitution. Every submodule works against a caller-supplied VPC, subnet, or route-table ID, so it can extend a VPC this module did not create. A supplied KMS key, log group, or security group is a drop-in for a managed one: outputs (`flow_log_kms_key_arn`, `flow_log_group_arn`, `endpoint_security_group_id`, `security_group_ids`) and downstream wiring are identical either way.
- Interface segregation. `internet`, `endpoints`, and `flow_logs` are optional objects; a private VPC needs `name`, a CIDR (`cidr_block` or `ipam`), and one tier. Each optional object carries only the inputs of its concern, and the root passes them through without reinterpretation.
- Dependency inversion. The root depends on identifiers (`transit_gateway_id`, `vpc_peering_connection_id`, `allocation_id`, `kms_key_arn`, `log_group_arn`, `security_group_ids`), never on how they were produced. Partition, region, and account are inputs; the only data-source fallback is in `flow-logs`, where the key policy must name a log-group ARN before the group exists.

The full rationale, including why the v0.x root and `modules/workload` were replaced, is in [docs/DESIGN.md](docs/DESIGN.md).

## Compatibility and scope

- Terraform `>= 1.7.0, < 2.0.0`. AWS provider `>= 6.35.0, < 7.0.0`.
- IPv4 addressing: an explicit primary CIDR or a VPC IPAM allocation, secondary IPv4 CIDRs, explicit or derived subnet CIDRs. Route destinations may be IPv6 and an egress-only internet gateway can be created, but the module does not yet associate an IPv6 CIDR with the VPC or its subnets.
- Roadmap: IPv6 (VPC and subnet IPv6 CIDR associations, dual-stack subnets), network ACLs, DHCP option sets, and VPC Lattice. They will arrive as optional inputs and will not break the v1 interface.

## Versioning and releases

Releases follow semantic versioning: incompatible interface changes bump the major version, new optional inputs and outputs bump the minor version, fixes bump the patch version. Every release is a signed annotated tag `vX.Y.Z`.

Pin the full commit SHA of the release tag and record the tag in a comment, so the source cannot move under you:

```hcl
module "network" {
  source = "git::https://github.com/hatan4ik/aws.modules.vpc.git?ref=<commit-sha>" # v1.0.0
}

module "data_subnets" {
  source = "git::https://github.com/hatan4ik/aws.modules.vpc.git//modules/subnets?ref=<commit-sha>" # v1.0.0
}
```

The `module-release` workflow publishes an immutable GitHub release only from a GitHub-verified, signed, annotated semantic-version tag that points at the merged `main` revision; lightweight or unsigned tags are rejected before anything is published. With a GitHub-associated GPG or SSH signing key configured:

```bash
git fetch origin
git tag -s vX.Y.Z <commit> -m "vX.Y.Z"
git push origin vX.Y.Z
gh workflow run module-release.yml --ref vX.Y.Z -f release_tag=vX.Y.Z
```

Dispatch from the tag, never from `main`: the workflow verifies that the tag points at the revision it checked out, and a maintenance release for an older line (for example a 0.3.x fix after 1.0.0 landed on `main`) is cut from that line's commit.

Upgrading from 0.x: read [docs/UPGRADE-1.0.md](docs/UPGRADE-1.0.md) for the input and output mapping of the root and of `modules/workload`, the exact v1 call for the live sandbox-network root, and ready-to-paste `moved` blocks. All changes are listed in [CHANGELOG.md](CHANGELOG.md).

## Contributing

Development setup, the local quality gate, the test-first workflow, and the release process are described in [CONTRIBUTING.md](CONTRIBUTING.md). Security reports go through [SECURITY.md](SECURITY.md).

## License

Apache-2.0. See [LICENSE](LICENSE).

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.7.0, < 2.0.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.35.0, < 7.0.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 6.35.0, < 7.0.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_endpoints"></a> [endpoints](#module\_endpoints) | ./modules/endpoints | n/a |
| <a name="module_flow_logs"></a> [flow\_logs](#module\_flow\_logs) | ./modules/flow-logs | n/a |
| <a name="module_internet"></a> [internet](#module\_internet) | ./modules/internet | n/a |
| <a name="module_routes"></a> [routes](#module\_routes) | ./modules/routes | n/a |
| <a name="module_subnets"></a> [subnets](#module\_subnets) | ./modules/subnets | n/a |

## Resources

| Name | Type |
|------|------|
| [aws_default_security_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/default_security_group) | resource |
| [aws_vpc.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc) | resource |
| [aws_vpc_encryption_control.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_encryption_control) | resource |
| [aws_vpc_ipv4_cidr_block_association.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_ipv4_cidr_block_association) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_cidr_block"></a> [cidr\_block](#input\_cidr\_block) | Primary IPv4 CIDR of the VPC. Mutually exclusive with ipam. | `string` | `null` | no |
| <a name="input_enable_dns_hostnames"></a> [enable\_dns\_hostnames](#input\_enable\_dns\_hostnames) | Assign DNS hostnames to instances. | `bool` | `true` | no |
| <a name="input_enable_dns_support"></a> [enable\_dns\_support](#input\_enable\_dns\_support) | Enable DNS resolution through the Amazon-provided resolver. | `bool` | `true` | no |
| <a name="input_enable_network_address_usage_metrics"></a> [enable\_network\_address\_usage\_metrics](#input\_enable\_network\_address\_usage\_metrics) | Publish Network Address Usage metrics for the VPC. | `bool` | `true` | no |
| <a name="input_endpoints"></a> [endpoints](#input\_endpoints) | VPC endpoints. Interface endpoints are placed in the subnets of subnet\_tier; gateway endpoints are associated with the route tables of route\_table\_tiers. A locked-down HTTPS security group is created unless security\_group\_ids are supplied. | <pre>object({<br/>    create_security_group      = optional(bool, true)<br/>    security_group_name        = optional(string)<br/>    security_group_description = optional(string)<br/>    security_group_ids         = optional(set(string), [])<br/>    interface = optional(map(object({<br/>      service_name                                   = string<br/>      subnet_tier                                    = string<br/>      private_dns_enabled                            = optional(bool, true)<br/>      policy_json                                    = optional(string)<br/>      ip_address_type                                = optional(string)<br/>      dns_record_ip_type                             = optional(string)<br/>      private_dns_only_for_inbound_resolver_endpoint = optional(bool)<br/>    })), {})<br/>    gateway = optional(map(object({<br/>      service_name      = string<br/>      route_table_tiers = set(string)<br/>      policy_json       = optional(string)<br/>    })), {})<br/>  })</pre> | `null` | no |
| <a name="input_flow_logs"></a> [flow\_logs](#input\_flow\_logs) | VPC Flow Logs. The default delivers all traffic to a CloudWatch log group with one-year retention; set destination.kms\_key\_arn or destination.create\_kms\_key for a customer-managed key, destination.type = s3 for an S3 bucket, or null to disable. | <pre>object({<br/>    destination = optional(object({<br/>      type             = optional(string, "cloud-watch-logs")<br/>      log_group_name   = optional(string)<br/>      create_log_group = optional(bool, true)<br/>      log_group_arn    = optional(string)<br/>      log_group_class  = optional(string, "STANDARD")<br/>      kms_key_arn      = optional(string)<br/>      create_kms_key   = optional(bool, false)<br/>      s3_bucket_arn    = optional(string)<br/>      s3_options = optional(object({<br/>        file_format                = optional(string, "plain-text")<br/>        hive_compatible_partitions = optional(bool, false)<br/>        per_hour_partition         = optional(bool, false)<br/>      }))<br/>    }), {})<br/>    retention_in_days               = optional(number, 365)<br/>    traffic_type                    = optional(string, "ALL")<br/>    max_aggregation_interval        = optional(number, 60)<br/>    log_format                      = optional(string)<br/>    role_name                       = optional(string)<br/>    role_path                       = optional(string, "/")<br/>    role_permissions_boundary       = optional(string)<br/>    kms_key_deletion_window_in_days = optional(number, 30)<br/>    partition                       = optional(string)<br/>    region                          = optional(string)<br/>    account_id                      = optional(string)<br/>  })</pre> | `{}` | no |
| <a name="input_instance_tenancy"></a> [instance\_tenancy](#input\_instance\_tenancy) | Tenancy of instances launched in the VPC: default or dedicated. | `string` | `"default"` | no |
| <a name="input_internet"></a> [internet](#input\_internet) | Internet gateway, optional egress-only gateway, and NAT gateways. Null (the default) creates no internet path. nat\_gateways are keyed by a short name and placed in a subnet given as <tier>/<az\_key>. | <pre>object({<br/>    create_internet_gateway             = optional(bool, true)<br/>    create_egress_only_internet_gateway = optional(bool, false)<br/>    nat_gateways = optional(map(object({<br/>      subnet            = string<br/>      allocation_id     = optional(string)<br/>      connectivity_type = optional(string, "public")<br/>      private_ip        = optional(string)<br/>    })), {})<br/>  })</pre> | `null` | no |
| <a name="input_ipam"></a> [ipam](#input\_ipam) | Allocate the primary CIDR from an AWS VPC IPAM pool instead of cidr\_block. Subnets then derive their CIDRs with newbits and netnum. | <pre>object({<br/>    pool_id        = string<br/>    netmask_length = number<br/>  })</pre> | `null` | no |
| <a name="input_name"></a> [name](#input\_name) | VPC name. Tagged as Name on the VPC and used as the prefix of every subnet, route table, gateway, endpoint, and flow-log name. | `string` | n/a | yes |
| <a name="input_secondary_cidr_blocks"></a> [secondary\_cidr\_blocks](#input\_secondary\_cidr\_blocks) | Additional IPv4 CIDR blocks associated with the VPC. | `set(string)` | `[]` | no |
| <a name="input_subnets"></a> [subnets](#input\_subnets) | Subnet tiers keyed by tier name (the Tier tag), for example private, transit, public. Each tier lists its subnets by AZ key with an explicit cidr\_block or newbits and netnum, chooses per\_az or shared route tables, and declares routes whose targets are IDs or references to gateways this module creates (nat\_gateway\_key, internet\_gateway, egress\_only\_internet\_gateway). | <pre>map(object({<br/>    availability_zones = map(object({<br/>      availability_zone = string<br/>      cidr_block        = optional(string)<br/>      newbits           = optional(number)<br/>      netnum            = optional(number)<br/>    }))<br/>    route_tables                        = optional(string, "per_az")<br/>    map_public_ip_on_launch             = optional(bool, false)<br/>    private_dns_hostname_type_on_launch = optional(string)<br/>    allow_default_route                 = optional(bool, false)<br/>    routes = optional(map(object({<br/>      destination_cidr_block       = optional(string)<br/>      destination_ipv6_cidr_block  = optional(string)<br/>      destination_prefix_list_id   = optional(string)<br/>      transit_gateway_id           = optional(string)<br/>      nat_gateway_id               = optional(string)<br/>      nat_gateway_key              = optional(string)<br/>      gateway_id                   = optional(string)<br/>      internet_gateway             = optional(bool, false)<br/>      egress_only_gateway_id       = optional(string)<br/>      egress_only_internet_gateway = optional(bool, false)<br/>      vpc_peering_connection_id    = optional(string)<br/>      network_interface_id         = optional(string)<br/>      vpc_endpoint_id              = optional(string)<br/>      core_network_arn             = optional(string)<br/>      carrier_gateway_id           = optional(string)<br/>      local_gateway_id             = optional(string)<br/>    })), {})<br/>  }))</pre> | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to every resource. The module adds Name (and Tier on subnets and route tables) and never overrides caller tags. | `map(string)` | `{}` | no |
| <a name="input_vpc_encryption_control"></a> [vpc\_encryption\_control](#input\_vpc\_encryption\_control) | VPC Encryption Control mode: enforce (default), monitor, or null to leave it unmanaged. | `string` | `"enforce"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_cidr_block"></a> [cidr\_block](#output\_cidr\_block) | Primary IPv4 CIDR (known after apply for IPAM allocations). |
| <a name="output_default_security_group_id"></a> [default\_security\_group\_id](#output\_default\_security\_group\_id) | ID of the managed deny-all default security group. |
| <a name="output_egress_only_internet_gateway_id"></a> [egress\_only\_internet\_gateway\_id](#output\_egress\_only\_internet\_gateway\_id) | Egress-only internet gateway ID, or null. |
| <a name="output_encryption_control_mode"></a> [encryption\_control\_mode](#output\_encryption\_control\_mode) | VPC Encryption Control mode, or null when unmanaged. |
| <a name="output_endpoint_security_group_id"></a> [endpoint\_security\_group\_id](#output\_endpoint\_security\_group\_id) | ID of the interface-endpoint security group, or null. |
| <a name="output_flow_log_group_arn"></a> [flow\_log\_group\_arn](#output\_flow\_log\_group\_arn) | Flow-log CloudWatch log group ARN, or null. |
| <a name="output_flow_log_group_name"></a> [flow\_log\_group\_name](#output\_flow\_log\_group\_name) | Flow-log CloudWatch log group name, or null. |
| <a name="output_flow_log_id"></a> [flow\_log\_id](#output\_flow\_log\_id) | Flow log ID, or null. |
| <a name="output_flow_log_kms_key_arn"></a> [flow\_log\_kms\_key\_arn](#output\_flow\_log\_kms\_key\_arn) | KMS key encrypting the flow-log log group, or null. |
| <a name="output_flow_log_role_arn"></a> [flow\_log\_role\_arn](#output\_flow\_log\_role\_arn) | Flow-log delivery role ARN, or null. |
| <a name="output_flow_log_role_name"></a> [flow\_log\_role\_name](#output\_flow\_log\_role\_name) | Flow-log delivery role name, or null. |
| <a name="output_flow_logs"></a> [flow\_logs](#output\_flow\_logs) | Flow-log identifiers in the v0.1.x shape (id, log\_group\_name, kms\_key\_arn, role\_arn), or null when disabled. |
| <a name="output_gateway_endpoint_ids"></a> [gateway\_endpoint\_ids](#output\_gateway\_endpoint\_ids) | Gateway endpoint IDs keyed by endpoint key. |
| <a name="output_gateway_endpoint_prefix_list_ids"></a> [gateway\_endpoint\_prefix\_list\_ids](#output\_gateway\_endpoint\_prefix\_list\_ids) | Managed prefix list IDs of gateway endpoints keyed by endpoint key. |
| <a name="output_interface_endpoint_ids"></a> [interface\_endpoint\_ids](#output\_interface\_endpoint\_ids) | Interface endpoint IDs keyed by endpoint key. |
| <a name="output_internet_gateway_id"></a> [internet\_gateway\_id](#output\_internet\_gateway\_id) | Internet gateway ID, or null. |
| <a name="output_nat_gateway_ids"></a> [nat\_gateway\_ids](#output\_nat\_gateway\_ids) | NAT gateway IDs keyed by gateway key. |
| <a name="output_nat_gateway_public_ips"></a> [nat\_gateway\_public\_ips](#output\_nat\_gateway\_public\_ips) | Public IPs of public NAT gateways keyed by gateway key. |
| <a name="output_private_subnets"></a> [private\_subnets](#output\_private\_subnets) | The private tier in the v0.1.x shape (id, availability\_zone, cidr, route\_table\_id by AZ key); empty when no private tier exists. |
| <a name="output_route_table_ids_by_tier"></a> [route\_table\_ids\_by\_tier](#output\_route\_table\_ids\_by\_tier) | Route table IDs keyed by tier then AZ key (or shared). |
| <a name="output_secondary_cidr_blocks"></a> [secondary\_cidr\_blocks](#output\_secondary\_cidr\_blocks) | Secondary IPv4 CIDR blocks associated with the VPC. |
| <a name="output_subnet_cidr_blocks_by_tier"></a> [subnet\_cidr\_blocks\_by\_tier](#output\_subnet\_cidr\_blocks\_by\_tier) | Subnet CIDR blocks keyed by tier then AZ key (known at plan time for explicit CIDRs). |
| <a name="output_subnet_ids_by_tier"></a> [subnet\_ids\_by\_tier](#output\_subnet\_ids\_by\_tier) | Subnet IDs keyed by tier then AZ key. |
| <a name="output_subnets"></a> [subnets](#output\_subnets) | Subnets keyed by tier then AZ key: id, arn, cidr\_block, availability\_zone, route\_table\_id. |
| <a name="output_vpc"></a> [vpc](#output\_vpc) | VPC identifiers in the v0.1.x shape: id, arn, cidr. |
| <a name="output_vpc_arn"></a> [vpc\_arn](#output\_vpc\_arn) | VPC ARN. |
| <a name="output_vpc_id"></a> [vpc\_id](#output\_vpc\_id) | VPC ID. |
<!-- END_TF_DOCS -->
