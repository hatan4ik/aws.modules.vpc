# Network IPAM module

Creates a home-Region AWS VPC IPAM, a non-allocating enterprise IPv4 pool,
localized child pools, and optional RAM shares that grant only approved
workload accounts or Organizations principals access to a Regional pool.

The management-account prerequisite that delegates IPAM administration and
enables RAM organization sharing is implemented by the sibling
`ipam-organization-admin` module. Run that approved root first. IPAM creation
and RAM shares must be administered from the IPAM home Region.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.7.0, < 2.0.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.35.0, < 7.0.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.66.0 |
| <a name="provider_terraform"></a> [terraform](#provider\_terraform) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [aws_ram_principal_association.regional_pool](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ram_principal_association) | resource |
| [aws_ram_resource_association.regional_pool](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ram_resource_association) | resource |
| [aws_ram_resource_share.regional_pool](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ram_resource_share) | resource |
| [aws_vpc_ipam.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_ipam) | resource |
| [aws_vpc_ipam_pool.regional](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_ipam_pool) | resource |
| [aws_vpc_ipam_pool.top_level](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_ipam_pool) | resource |
| [aws_vpc_ipam_pool_cidr.regional](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_ipam_pool_cidr) | resource |
| [aws_vpc_ipam_pool_cidr.top_level](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_ipam_pool_cidr) | resource |
| [terraform_data.configuration](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [aws_partition.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/partition) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_home_region"></a> [home\_region](#input\_home\_region) | AWS Region in which the IPAM and its RAM shares are administered. The caller must run this module with a provider for this Region. | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Lowercase IPAM name used for the IPAM, pool, and RAM-share names. | `string` | n/a | yes |
| <a name="input_operating_regions"></a> [operating\_regions](#input\_operating\_regions) | All Regions in which this IPAM manages private address space, including home\_region. | `set(string)` | n/a | yes |
| <a name="input_regional_pools"></a> [regional\_pools](#input\_regional\_pools) | Regional private pools allocated from top\_level\_cidr. Each may be RAM-shared only with approved accounts or Organizations principals. | <pre>map(object({<br/>    locale                            = string<br/>    cidr                              = string<br/>    allocation_default_netmask_length = number<br/>    allocation_min_netmask_length     = optional(number)<br/>    allocation_max_netmask_length     = optional(number)<br/>    allocation_resource_tags          = optional(map(string), {})<br/>    ram_principals                    = optional(set(string), [])<br/>  }))</pre> | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Additional allocation and ownership tags. Name and Component tags are computed by the module. | `map(string)` | `{}` | no |
| <a name="input_top_level_cidr"></a> [top\_level\_cidr](#input\_top\_level\_cidr) | Enterprise-approved IPv4 CIDR reserved for this IPAM's top-level private pool. It must be approved as non-overlapping before any apply. | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_ipam"></a> [ipam](#output\_ipam) | IPAM identifiers and private scope owned by the Network account. |
| <a name="output_regional_pools"></a> [regional\_pools](#output\_regional\_pools) | Approved regional IPAM pool IDs/ARNs and their RAM-share status for reviewed workload-root configuration. |
<!-- END_TF_DOCS -->
