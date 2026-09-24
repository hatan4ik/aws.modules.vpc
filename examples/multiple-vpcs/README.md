# Multiple VPCs

Creates a fleet of VPCs from one root module by using `for_each` on the module
block. `aws.modules.vpc` provisions exactly one VPC per call on purpose: a VPC
is the unit that owns its CIDR, tiers, gateways, endpoints, and flow logs, and
a plan error names the one VPC that caused it. Fleets are therefore expressed
in the caller as a map of VPC specifications, never as a list inside the
module. Each entry supplies its CIDR and its tiers; the module derives
`<name_prefix>-<key>`, tags every resource with `Network = <key>`, and creates a
flow-log key and log group per VPC. Adding a VPC is adding a map entry, removing
one destroys exactly that VPC, and because every VPC has its own module instance
you can still `-target` or `moved` a single one.

## Run

Declare the fleet in a `terraform.tfvars`:

```hcl
vpcs = {
  shared-services = {
    cidr_block = "10.10.0.0/16"
    subnets = {
      private = {
        availability_zones = {
          az1 = { availability_zone = "us-east-2a", newbits = 4, netnum = 0 }
          az2 = { availability_zone = "us-east-2b", newbits = 4, netnum = 1 }
        }
      }
    }
  }
  workloads = {
    cidr_block = "10.20.0.0/16"
    subnets = {
      private = {
        availability_zones = {
          az1 = { availability_zone = "us-east-2a", cidr_block = "10.20.0.0/20" }
          az2 = { availability_zone = "us-east-2b", cidr_block = "10.20.16.0/20" }
        }
      }
      data = {
        availability_zones = {
          az1 = { availability_zone = "us-east-2a", cidr_block = "10.20.32.0/22" }
          az2 = { availability_zone = "us-east-2b", cidr_block = "10.20.36.0/22" }
        }
      }
    }
  }
}
```

```sh
terraform init && terraform plan
```

Connecting the VPCs (peering or a Transit Gateway) is a separate concern; the
`route_table_ids_by_tier` output lists the tables that would receive those
routes.

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
| <a name="input_name_prefix"></a> [name\_prefix](#input\_name\_prefix) | Prefix of every VPC name; the map key is appended (<prefix>-<key>). | `string` | `"platform"` | no |
| <a name="input_region"></a> [region](#input\_region) | AWS region every VPC is created in. | `string` | `"us-east-2"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to every resource of every VPC. | `map(string)` | `{}` | no |
| <a name="input_vpcs"></a> [vpcs](#input\_vpcs) | VPCs keyed by a short name that becomes the suffix of the VPC name and its Network tag. Each declares its primary CIDR and its subnet tiers; every subnet names an Availability Zone and either an explicit cidr\_block or newbits and netnum relative to the VPC CIDR. CIDRs must not overlap across VPCs that will be connected. | <pre>map(object({<br/>    cidr_block = string<br/>    subnets = map(object({<br/>      availability_zones = map(object({<br/>        availability_zone = string<br/>        cidr_block        = optional(string)<br/>        newbits           = optional(number)<br/>        netnum            = optional(number)<br/>      }))<br/>      route_tables = optional(string, "per_az")<br/>    }))<br/>  }))</pre> | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_route_table_ids_by_tier"></a> [route\_table\_ids\_by\_tier](#output\_route\_table\_ids\_by\_tier) | Route table IDs keyed by VPC key, then tier, then AZ key; the tables to add routes to when the VPCs are connected. |
| <a name="output_subnet_ids_by_tier"></a> [subnet\_ids\_by\_tier](#output\_subnet\_ids\_by\_tier) | Subnet IDs keyed by VPC key, then tier, then AZ key. |
| <a name="output_vpc_ids"></a> [vpc\_ids](#output\_vpc\_ids) | VPC IDs keyed by VPC key. |
<!-- END_TF_DOCS -->
