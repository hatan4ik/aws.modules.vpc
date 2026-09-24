# subnets

Owns one subnet tier of a VPC: the subnets keyed by a stable AZ key, their route tables (one per subnet or one shared), and the associations between them. It is a separate module because a tier is the unit the platform discovers (`Tier = <tier>`) and the unit that gets its own routing, and because a tier can be added to a VPC this repository did not create. Routes are deliberately not declared here; the [`routes`](../routes) module installs them, so a tier can route through gateways that are created after it without a dependency cycle.

## Usage

```hcl
module "private" {
  source = "git::https://github.com/hatan4ik/aws.modules.vpc.git//modules/subnets?ref=<commit-sha>" # v1.0.0

  vpc_id         = "vpc-0123456789abcdef0"
  vpc_cidr_block = "10.64.0.0/16"
  name           = "sandbox-network-dev"
  tier           = "private"

  availability_zones = {
    az1 = { availability_zone = "us-east-2a", cidr_block = "10.64.0.0/20" }
    az2 = { availability_zone = "us-east-2b", newbits = 4, netnum = 1 } # 10.64.16.0/20
  }

  tags = { Environment = "dev" }
}

module "transit" {
  source = "git::https://github.com/hatan4ik/aws.modules.vpc.git//modules/subnets?ref=<commit-sha>" # v1.0.0

  vpc_id       = "vpc-0123456789abcdef0"
  name         = "sandbox-network-dev"
  tier         = "transit"
  route_tables = "shared"

  availability_zones = {
    az1 = { availability_zone = "us-east-2a", cidr_block = "10.64.255.0/28" }
    az2 = { availability_zone = "us-east-2b", cidr_block = "10.64.255.16/28" }
  }

  tags = { Environment = "dev" }
}
```

## Behaviour

- Names and tags. Every subnet and route table is tagged `Name = <name>-<tier>-<az_key>` and `Tier = <tier>`; a shared route table is `Name = <name>-<tier>`. Caller tags are merged first and never overridden. `name` is the VPC name (3 to 51 lowercase characters and hyphens); `tier` is 1 to 31 lowercase characters and hyphens starting with a letter, because it becomes a tag value; AZ keys are 1 to 32 characters of letters, digits, underscores, or hyphens, because they become part of a resource address and of the `Name` tag. The platform roots select subnets and route tables by `tag:Tier`, so the tier value is a contract, not a label.
- `per_az` versus `shared`. The default, `per_az`, creates `aws_route_table.this["<az_key>"]` for every subnet and associates each subnet with its own table, so a routing change or a table problem is confined to one Availability Zone. `shared` creates `aws_route_table.this["shared"]` and associates every subnet with it, which suits a tier whose routing is identical everywhere and whose table count matters (a transit tier, for example). Switching an existing tier replaces its tables and associations because the keys change.
- `cidr_block` versus `newbits`/`netnum`. Each subnet declares exactly one form. An explicit `cidr_block` is known at plan time. `newbits` (1 to 16) and `netnum` (a non-negative whole number) are evaluated as `cidrsubnet(vpc_cidr_block, newbits, netnum)`, which is the only form that works when the VPC CIDR comes from IPAM and is unknown until apply; `vpc_cidr_block` is then required, and a precondition on the subnet names it if it is missing. The two forms may be mixed within a tier.
- One Availability Zone per subnet within a tier, and at least one subnet. Two subnets of the same tier in the same zone are rejected at plan time.
- Public-tier settings pass through per tier: `map_public_ip_on_launch` (default `false`) and `private_dns_hostname_type_on_launch` (`ip-name`, `resource-name`, or unset).
- Outputs are keyed by AZ key: `subnets` (`id`, `arn`, `cidr_block`, `availability_zone`, `route_table_id`), `subnet_ids`, `subnet_cidr_blocks` (known at plan time for explicit CIDRs), and `route_table_ids` (keyed by AZ key for `per_az` or by `shared`), which is exactly the map the `routes` module and gateway endpoints consume.

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
| [aws_route_table.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table) | resource |
| [aws_route_table_association.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association) | resource |
| [aws_subnet.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_availability_zones"></a> [availability\_zones](#input\_availability\_zones) | Subnets of the tier keyed by a stable AZ key. Each declares either an explicit cidr\_block or newbits and netnum relative to vpc\_cidr\_block. | <pre>map(object({<br/>    availability_zone = string<br/>    cidr_block        = optional(string)<br/>    newbits           = optional(number)<br/>    netnum            = optional(number)<br/>  }))</pre> | n/a | yes |
| <a name="input_map_public_ip_on_launch"></a> [map\_public\_ip\_on\_launch](#input\_map\_public\_ip\_on\_launch) | Assign public IPv4 addresses to instances launched in the tier. Only meaningful for a public tier. | `bool` | `false` | no |
| <a name="input_name"></a> [name](#input\_name) | VPC name; subnet and route-table names are <name>-<tier>-<az\_key>. | `string` | n/a | yes |
| <a name="input_private_dns_hostname_type_on_launch"></a> [private\_dns\_hostname\_type\_on\_launch](#input\_private\_dns\_hostname\_type\_on\_launch) | Hostname type for instances launched in the tier: ip-name or resource-name. | `string` | `null` | no |
| <a name="input_route_tables"></a> [route\_tables](#input\_route\_tables) | per\_az creates one route table per subnet (the resilient default); shared creates one route table for the tier. | `string` | `"per_az"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to every subnet and route table; Name and Tier are added by the module. | `map(string)` | `{}` | no |
| <a name="input_tier"></a> [tier](#input\_tier) | Tier identifier, also the Tier tag value the platform uses to discover subnets and route tables (for example private, transit, public). | `string` | n/a | yes |
| <a name="input_vpc_cidr_block"></a> [vpc\_cidr\_block](#input\_vpc\_cidr\_block) | Primary IPv4 CIDR of the VPC. Required when any subnet is allocated with newbits and netnum instead of an explicit cidr\_block. | `string` | `null` | no |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | VPC the tier belongs to. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_route_table_ids"></a> [route\_table\_ids](#output\_route\_table\_ids) | Route table IDs keyed by AZ key (per\_az) or by "shared". |
| <a name="output_subnet_cidr_blocks"></a> [subnet\_cidr\_blocks](#output\_subnet\_cidr\_blocks) | Subnet CIDR blocks keyed by AZ key, known at plan time. |
| <a name="output_subnet_ids"></a> [subnet\_ids](#output\_subnet\_ids) | Subnet IDs keyed by AZ key. |
| <a name="output_subnets"></a> [subnets](#output\_subnets) | Subnets keyed by AZ key: id, arn, cidr\_block, availability\_zone, route\_table\_id. |
| <a name="output_tier"></a> [tier](#output\_tier) | Tier identifier of these subnets. |
<!-- END_TF_DOCS -->
