# internet

Owns the internet path of a VPC: the internet gateway, an optional egress-only internet gateway for IPv6, and NAT gateways with their Elastic IPs. It is a separate module because an internet path is a deliberate, reviewable decision that most VPCs in this platform do not take, and because the root creates nothing here unless `internet` is set. Routes to these gateways are declared on the tiers (`internet_gateway = true`, `nat_gateway_key`, `egress_only_internet_gateway = true`) and installed by the [`routes`](../routes) module.

## Usage

```hcl
module "internet" {
  source = "git::https://github.com/hatan4ik/aws.modules.vpc.git//modules/internet?ref=<commit-sha>" # v1.0.0

  vpc_id = "vpc-0123456789abcdef0"
  name   = "orders-network"

  nat_gateways = {
    az1 = { subnet_id = module.public.subnet_ids["az1"] }
    az2 = { subnet_id = module.public.subnet_ids["az2"], allocation_id = "eipalloc-0123456789abcdef0" }
  }

  tags = { Environment = "prod" }
}

module "private_routes" {
  source = "git::https://github.com/hatan4ik/aws.modules.vpc.git//modules/routes?ref=<commit-sha>" # v1.0.0

  route_table_ids     = module.private.route_table_ids
  allow_default_route = true

  routes = {
    internet = { destination_cidr_block = "0.0.0.0/0", nat_gateway_id = module.internet.nat_gateway_ids["az1"] }
  }
}
```

## Behaviour

- Internet gateway. `create_internet_gateway` (default `true`) creates `<name>-igw`. It is required for public NAT gateways and for public subnets; `internet_gateway_id` is null without it.
- Egress-only gateway. `create_egress_only_internet_gateway` (default `false`) creates `<name>-eigw` for IPv6-only outbound traffic. `egress_only_internet_gateway_id` is null without it.
- NAT gateways with created or supplied EIPs. Each entry of `nat_gateways` is keyed by a short stable name (normally the AZ key; 1 to 32 characters of letters, digits, underscores, or hyphens) and sits in `subnet_id`. A public gateway (`connectivity_type = "public"`, the default) gets a created Elastic IP `<name>-nat-<key>` unless `allocation_id` names one you own; created EIPs and NAT gateways depend on the internet gateway, and a public gateway with `create_internet_gateway = false` is rejected by a precondition. `private_ip` pins the gateway's private address.
- Private NAT. `connectivity_type = "private"` creates a NAT gateway with no public address, for traffic to other private networks through a Transit Gateway or peering; it needs no internet gateway and no Elastic IP, and an `allocation_id` on a private gateway is rejected at plan time. Private gateways are absent from `nat_gateway_public_ips`.
- Names and outputs. Gateways are `<name>-igw`, `<name>-eigw`, and `<name>-nat-<key>`; the Elastic IP shares the NAT gateway's name. Outputs: `internet_gateway_id`, `egress_only_internet_gateway_id`, `nat_gateway_ids` and `nat_gateway_public_ips` keyed by gateway key, and `eip_allocation_ids` for the Elastic IPs the module created.
- One NAT gateway per Availability Zone is the resilient shape; one for the whole VPC is the cheap one. The module takes either. In the root, a tier's default route names one `nat_gateway_key`, so a tier whose zones must each use their own gateway is declared as one tier per zone.

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
| [aws_egress_only_internet_gateway.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/egress_only_internet_gateway) | resource |
| [aws_eip.nat](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eip) | resource |
| [aws_internet_gateway.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/internet_gateway) | resource |
| [aws_nat_gateway.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/nat_gateway) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_create_egress_only_internet_gateway"></a> [create\_egress\_only\_internet\_gateway](#input\_create\_egress\_only\_internet\_gateway) | Create an egress-only internet gateway for IPv6-only outbound traffic. | `bool` | `false` | no |
| <a name="input_create_internet_gateway"></a> [create\_internet\_gateway](#input\_create\_internet\_gateway) | Create an internet gateway. Required for public NAT gateways and public subnets. | `bool` | `true` | no |
| <a name="input_name"></a> [name](#input\_name) | VPC name; the internet gateway is <name>-igw and NAT gateways <name>-nat-<key>. | `string` | n/a | yes |
| <a name="input_nat_gateways"></a> [nat\_gateways](#input\_nat\_gateways) | NAT gateways keyed by a stable identifier (normally the AZ key). Each sits in a subnet; a public NAT gateway gets a created Elastic IP unless allocation\_id is supplied; a private NAT gateway needs neither. | <pre>map(object({<br/>    subnet_id         = string<br/>    allocation_id     = optional(string)<br/>    connectivity_type = optional(string, "public")<br/>    private_ip        = optional(string)<br/>  }))</pre> | `{}` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to every gateway and Elastic IP; Name is added by the module. | `map(string)` | `{}` | no |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | VPC that receives the gateways. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_egress_only_internet_gateway_id"></a> [egress\_only\_internet\_gateway\_id](#output\_egress\_only\_internet\_gateway\_id) | Egress-only internet gateway ID, or null. |
| <a name="output_eip_allocation_ids"></a> [eip\_allocation\_ids](#output\_eip\_allocation\_ids) | Allocation IDs of the Elastic IPs created for NAT gateways, keyed by gateway key. |
| <a name="output_internet_gateway_id"></a> [internet\_gateway\_id](#output\_internet\_gateway\_id) | Internet gateway ID, or null. |
| <a name="output_nat_gateway_ids"></a> [nat\_gateway\_ids](#output\_nat\_gateway\_ids) | NAT gateway IDs keyed by gateway key. |
| <a name="output_nat_gateway_public_ips"></a> [nat\_gateway\_public\_ips](#output\_nat\_gateway\_public\_ips) | Public IPs of public NAT gateways keyed by gateway key. |
<!-- END_TF_DOCS -->
