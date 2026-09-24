# Three tiers with NAT egress

A `public` tier that routes to an internet gateway, a `private` tier whose
default route goes through a NAT gateway in `public/az1`, and an isolated `data`
tier with no routes at all, each spread across two Availability Zones and sized
relative to the VPC CIDR with `newbits` and `netnum`. An internet path is never
implicit: it exists only because `internet` is declared, the two tiers that use
it set `allow_default_route = true` (without it a `0.0.0.0/0` route is rejected at
plan time), and the module's `internet_path_declared` check warns on every plan
so the choice stays visible. VPC Encryption Control runs in `monitor` mode here
instead of the default `enforce`. Public subnets keep `map_public_ip_on_launch`
off; anything that needs a public address gets one explicitly.

Routes are installed into every route table of a tier, so this layout has one
NAT gateway serving both private subnets, which is the cost-conscious choice
and means an outage of `az1` also takes down egress from `az2`. Per-AZ NAT
resilience needs one tier per Availability Zone, each with its own shared route
table and its own gateway key; the trade-off is that the `Tier` tag then reads
`private-az1`/`private-az2` rather than `private`, and the module's `single_az`
check warns for each one-subnet tier:

```hcl
internet = {
  nat_gateways = {
    az1 = { subnet = "public/az1" }
    az2 = { subnet = "public/az2" }
  }
}

subnets = {
  # public and data tiers as above, then one private tier per AZ:
  private-az1 = {
    availability_zones  = { az1 = { availability_zone = "us-east-2a", newbits = 4, netnum = 1 } }
    route_tables        = "shared"
    allow_default_route = true
    routes              = { internet = { destination_cidr_block = "0.0.0.0/0", nat_gateway_key = "az1" } }
  }
  private-az2 = {
    availability_zones  = { az2 = { availability_zone = "us-east-2b", newbits = 4, netnum = 2 } }
    route_tables        = "shared"
    allow_default_route = true
    routes              = { internet = { destination_cidr_block = "0.0.0.0/0", nat_gateway_key = "az2" } }
  }
}
```

## Run

```sh
terraform init
terraform plan \
  -var cidr_block=10.80.0.0/16 \
  -var 'availability_zones={az1="us-east-2a",az2="us-east-2b"}'
```

With `10.80.0.0/16` the public subnets are `10.80.0.0/24` and `10.80.1.0/24`,
the private subnets `10.80.16.0/20` and `10.80.32.0/20`, and the data subnets
`10.80.48.0/22` and `10.80.52.0/22`. A NAT gateway and its Elastic IP are billed
hourly from the moment they are created.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.7.0, < 2.0.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.35.0, < 7.0.0 |

## Providers

No providers.

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_vpc"></a> [vpc](#module\_vpc) | ../../ | n/a |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_availability_zones"></a> [availability\_zones](#input\_availability\_zones) | Availability Zone of each subnet, keyed by the stable AZ keys (az1, az2) that name the subnets, route tables, and NAT gateway. All three tiers use the same zones. | <pre>object({<br/>    az1 = string<br/>    az2 = string<br/>  })</pre> | n/a | yes |
| <a name="input_cidr_block"></a> [cidr\_block](#input\_cidr\_block) | Primary IPv4 CIDR of the VPC. The tier layout (public /24s, private /20s, data /22s for a /16) is relative to it, so use a /16 to /20 block. | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | VPC name; also the prefix of every subnet, route table, gateway, and flow-log resource name. | `string` | `"web-network"` | no |
| <a name="input_region"></a> [region](#input\_region) | AWS region the VPC is created in. | `string` | `"us-east-2"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to every resource. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_internet_gateway_id"></a> [internet\_gateway\_id](#output\_internet\_gateway\_id) | ID of the internet gateway the public tier routes through. |
| <a name="output_nat_gateway_public_ips"></a> [nat\_gateway\_public\_ips](#output\_nat\_gateway\_public\_ips) | Public IP of each NAT gateway keyed by gateway key; the source address of outbound traffic from the private tier. |
| <a name="output_route_table_ids_by_tier"></a> [route\_table\_ids\_by\_tier](#output\_route\_table\_ids\_by\_tier) | Route table IDs keyed by tier then AZ key. |
| <a name="output_subnet_ids_by_tier"></a> [subnet\_ids\_by\_tier](#output\_subnet\_ids\_by\_tier) | Subnet IDs keyed by tier then AZ key. |
| <a name="output_vpc_id"></a> [vpc\_id](#output\_vpc\_id) | ID of the VPC. |
<!-- END_TF_DOCS -->
