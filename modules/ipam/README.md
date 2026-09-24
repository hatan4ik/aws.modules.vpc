# IPAM submodule

Creates a home-Region AWS VPC IPAM, a non-allocating enterprise IPv4 pool, one
localized child pool per approved Region, and optional RAM shares that grant
approved workload accounts or Organizations principals access to a Regional
pool. It runs on its own from the Network account of a landing zone; the root
module consumes a Regional pool through `ipam.pool_id` when a VPC allocates its
CIDR from IPAM instead of declaring `cidr_block`.

## What it creates

- One `aws_vpc_ipam` in the advanced tier, operating in every Region of
  `operating_regions`, administered from `home_region`.
- A top-level pool holding `top_level_cidr` with no locale, so it only
  reserves space and delegates through its children; nothing allocates from
  it directly.
- One child pool per `regional_pools` entry, localized to its `locale`, with
  the default, minimum, and maximum VPC netmask lengths and the allocation
  resource tags the platform requires.
- For every pool that lists `ram_principals`, one RAM share carrying the
  AWS-managed `AWSRAMDefaultPermissionsIpamPool` permission, with external
  principals disabled, and one principal association per principal.

## Rules it enforces

- `operating_regions` must include `home_region`, and every pool `locale`
  must be an operating Region; both are preconditions on the IPAM, so nothing
  is created when they fail.
- Exactly one pool per locale, with IPv4 CIDRs and netmask lengths from /16
  through /28 that are consistent with each other.
- `ram_principals` accepts 12-digit account IDs and Organizations
  organization or OU ARNs only; IAM principals are rejected because the
  platform shares pools with accounts, never with roles.

## Prerequisite

The management-account step that delegates IPAM administration to the Network
account and enables RAM sharing with the organization is the sibling
[`ipam-organization-admin`](../ipam-organization-admin/README.md) submodule.
Apply it first. Run this module with a provider configured for `home_region`:
AWS accepts IPAM pool shares only there.

## Usage

```hcl
module "ipam" {
  source = "git::https://github.com/hatan4ik/aws.modules.vpc.git//modules/ipam?ref=<commit-sha> # v1.0.0"

  name              = "platform-ipam"
  home_region       = "us-east-2"
  operating_regions = ["us-east-2", "us-west-2"]
  top_level_cidr    = "10.128.0.0/9"

  regional_pools = {
    use2 = {
      locale                            = "us-east-2"
      cidr                              = "10.128.0.0/16"
      allocation_default_netmask_length = 20
      allocation_min_netmask_length     = 20
      allocation_max_netmask_length     = 24
      ram_principals                    = ["111122223333"]
    }
  }

  tags = { Owner = "network" }
}
```

A workload VPC then allocates from the shared pool:

```hcl
module "vpc" {
  source = "git::https://github.com/hatan4ik/aws.modules.vpc.git?ref=<commit-sha> # v1.0.0"

  name = "orders-network"
  ipam = { pool_id = module.ipam.regional_pools["use2"].id, netmask_length = 20 }
  # ...
}
```

## Notes

- `partition` is optional; when null the module reads it from the provider.
  Declare it to keep the module free of data sources.
- Upgrading from v0.3.0: the `terraform_data.configuration` carrier that held
  the cross-variable rules was removed and its rules moved onto
  `aws_vpc_ipam.this`. The first plan destroys that `terraform_data` instance
  and changes nothing in AWS.

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
| [aws_ram_principal_association.regional_pool](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ram_principal_association) | resource |
| [aws_ram_resource_association.regional_pool](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ram_resource_association) | resource |
| [aws_ram_resource_share.regional_pool](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ram_resource_share) | resource |
| [aws_vpc_ipam.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_ipam) | resource |
| [aws_vpc_ipam_pool.regional](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_ipam_pool) | resource |
| [aws_vpc_ipam_pool.top_level](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_ipam_pool) | resource |
| [aws_vpc_ipam_pool_cidr.regional](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_ipam_pool_cidr) | resource |
| [aws_vpc_ipam_pool_cidr.top_level](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_ipam_pool_cidr) | resource |
| [aws_partition.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/partition) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_home_region"></a> [home\_region](#input\_home\_region) | AWS Region in which the IPAM and its RAM shares are administered. The caller must run this module with a provider for this Region. | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Lowercase IPAM name used for the IPAM, pool, and RAM-share names. | `string` | n/a | yes |
| <a name="input_operating_regions"></a> [operating\_regions](#input\_operating\_regions) | All Regions in which this IPAM manages private address space, including home\_region. | `set(string)` | n/a | yes |
| <a name="input_partition"></a> [partition](#input\_partition) | AWS partition used in the RAM permission ARN (aws, aws-cn, aws-us-gov). Resolved from the provider when null. | `string` | `null` | no |
| <a name="input_regional_pools"></a> [regional\_pools](#input\_regional\_pools) | Regional private pools allocated from top\_level\_cidr. Each may be RAM-shared only with approved accounts or Organizations principals. | <pre>map(object({<br/>    locale                            = string<br/>    cidr                              = string<br/>    allocation_default_netmask_length = number<br/>    allocation_min_netmask_length     = optional(number)<br/>    allocation_max_netmask_length     = optional(number)<br/>    allocation_resource_tags          = optional(map(string), {})<br/>    ram_principals                    = optional(set(string), [])<br/>  }))</pre> | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Additional allocation and ownership tags. Name and Component tags are computed by the module. | `map(string)` | `{}` | no |
| <a name="input_top_level_cidr"></a> [top\_level\_cidr](#input\_top\_level\_cidr) | Enterprise-approved IPv4 CIDR reserved for this IPAM's top-level private pool. It must be approved as non-overlapping before any apply. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_ipam"></a> [ipam](#output\_ipam) | IPAM identifiers and private scope owned by the Network account. |
| <a name="output_regional_pools"></a> [regional\_pools](#output\_regional\_pools) | Approved regional IPAM pool IDs/ARNs and their RAM-share status for reviewed workload-root configuration. |
<!-- END_TF_DOCS -->
