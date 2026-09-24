# routes

Owns route entries: a map of routes installed into a map of route tables, one `aws_route` per pair. It is a separate module because a route's target is often a gateway that exists only after the tier does (a NAT gateway in the public tier, a Transit Gateway attachment, a Gateway Load Balancer endpoint), and keeping entries apart from tables lets the root create tiers, then gateways, then routes without a cycle. It is purely ID-based: it never looks anything up and never creates a table.

## Usage

```hcl
module "private_routes" {
  source = "git::https://github.com/hatan4ik/aws.modules.vpc.git//modules/routes?ref=<commit-sha>" # v1.0.0

  route_table_ids = module.private.route_table_ids # { az1 = "rtb-...", az2 = "rtb-..." }

  routes = {
    to-hub     = { destination_cidr_block = "10.0.0.0/8", transit_gateway_id = "tgw-0123456789abcdef0" }
    to-corp    = { destination_prefix_list_id = "pl-0123456789abcdef0", transit_gateway_id = "tgw-0123456789abcdef0" }
    to-inspect = { destination_cidr_block = "192.168.0.0/16", vpc_endpoint_id = "vpce-0123456789abcdef0" }
  }
}

module "public_routes" {
  source = "git::https://github.com/hatan4ik/aws.modules.vpc.git//modules/routes?ref=<commit-sha>" # v1.0.0

  route_table_ids     = module.public.route_table_ids
  allow_default_route = true

  routes = {
    internet = { destination_cidr_block = "0.0.0.0/0", gateway_id = "igw-0123456789abcdef0" }
  }
}
```

## Behaviour

- One destination and one target. Each route names exactly one of `destination_cidr_block`, `destination_ipv6_cidr_block`, or `destination_prefix_list_id`, and exactly one of `transit_gateway_id`, `nat_gateway_id`, `gateway_id`, `egress_only_gateway_id`, `vpc_peering_connection_id`, `network_interface_id`, `vpc_endpoint_id`, `core_network_arn`, `carrier_gateway_id`, or `local_gateway_id`. Zero or two of either fails validation at plan time with a message that says so.
- Installed into every table given. Routes are the cross product of `route_table_ids` and `routes`, addressed as `aws_route.this["<route table key>/<route key>"]` (`az1/to-hub`, `shared/to-hub`), so a tier with one table per Availability Zone gets identical routing in each zone. Three routes across two tables are six resources; `route_count` reports the total. An empty `routes` map creates nothing.
- Default-route guard. `0.0.0.0/0` and `::/0` are rejected by a precondition on every route unless `allow_default_route = true`. The flag is per module call, which in the root is per tier, so a private tier cannot be given an internet path by accident.
- Endpoint targets need CIDR destinations. A route whose target is `vpc_endpoint_id` (a Gateway Load Balancer endpoint) with a `destination_prefix_list_id` is rejected at plan time, because AWS does not accept prefix-list destinations for endpoint targets and the failure would otherwise surface at apply.
- Route table IDs are validated (`rtb-...`) and route keys are 1 to 63 characters of letters, digits, underscores, dots, or hyphens. Keys are addresses: renaming a key replaces that route in every table.
- In the root, targets that name gateways the root creates (`nat_gateway_key`, `internet_gateway = true`, `egress_only_internet_gateway = true`) are resolved to IDs before this module is called, so a standalone caller passes IDs only.

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

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_route.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_allow_default_route"></a> [allow\_default\_route](#input\_allow\_default\_route) | Permit 0.0.0.0/0 and ::/0 destinations. Off by default so a private tier cannot be given an internet path by accident. | `bool` | `false` | no |
| <a name="input_route_table_ids"></a> [route\_table\_ids](#input\_route\_table\_ids) | Route tables that receive every route, keyed by a stable identifier (typically the AZ key or "shared"). | `map(string)` | n/a | yes |
| <a name="input_routes"></a> [routes](#input\_routes) | Routes keyed by a stable identifier. Each names exactly one destination (destination\_cidr\_block, destination\_ipv6\_cidr\_block, or destination\_prefix\_list\_id) and exactly one target. | <pre>map(object({<br/>    destination_cidr_block      = optional(string)<br/>    destination_ipv6_cidr_block = optional(string)<br/>    destination_prefix_list_id  = optional(string)<br/>    transit_gateway_id          = optional(string)<br/>    nat_gateway_id              = optional(string)<br/>    gateway_id                  = optional(string)<br/>    egress_only_gateway_id      = optional(string)<br/>    vpc_peering_connection_id   = optional(string)<br/>    network_interface_id        = optional(string)<br/>    vpc_endpoint_id             = optional(string)<br/>    core_network_arn            = optional(string)<br/>    carrier_gateway_id          = optional(string)<br/>    local_gateway_id            = optional(string)<br/>  }))</pre> | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_route_count"></a> [route\_count](#output\_route\_count) | Number of routes installed (route tables x routes). |
| <a name="output_route_ids"></a> [route\_ids](#output\_route\_ids) | Route IDs keyed by <route table key>/<route key>. |
<!-- END_TF_DOCS -->
