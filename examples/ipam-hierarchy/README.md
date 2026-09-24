# IPAM hierarchy

Builds the address-management plane that `ipam = { pool_id, netmask_length }`
allocations draw from, using the two IPAM submodules directly. The management
account first delegates the Network account as the organization's VPC IPAM
administrator and enables RAM sharing with the organization; that call runs
through the `management` provider alias, which assumes a role in the management
account, while the default provider carries the Network account's own
credentials. The Network account then creates a home-Region IPAM with a
non-allocating enterprise pool and one allocatable child pool per Region, each
RAM-shared only to the accounts or organizational units it lists. Both steps run
in the IPAM home Region because AWS accepts pool shares only there, and the
module rejects a pool whose locale is not an operating Region.

The `regional_pool_ids` output is the contract for workload VPCs: promote the
reviewed value into their configuration as `ipam.pool_id` (see
`examples/private-endpoints-ipam`) rather than reading this state remotely.

## Run

Declare the hierarchy in a `terraform.tfvars`:

```hcl
management_role_arn = "arn:aws:iam::111111111111:role/OrganizationAdministrator"
network_account_id  = "222222222222"
operating_regions   = ["us-east-2", "us-west-2"]
top_level_cidr      = "10.0.0.0/8"

regional_pools = {
  us-east-2 = {
    locale                            = "us-east-2"
    cidr                              = "10.0.0.0/12"
    allocation_default_netmask_length = 20
    allocation_min_netmask_length     = 16
    allocation_max_netmask_length     = 24
    ram_principals                    = ["arn:aws:organizations::111111111111:ou/o-example/ou-example-workloads"]
  }
  us-west-2 = {
    locale                            = "us-west-2"
    cidr                              = "10.16.0.0/12"
    allocation_default_netmask_length = 20
    ram_principals                    = ["333333333333"]
  }
}
```

```sh
terraform init && terraform plan
```

An IPAM in the advanced tier is billed per active IP address it manages; delete
the hierarchy when an experiment is over.

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
| <a name="module_ipam"></a> [ipam](#module\_ipam) | ../../modules/ipam | n/a |
| <a name="module_ipam_organization_admin"></a> [ipam\_organization\_admin](#module\_ipam\_organization\_admin) | ../../modules/ipam-organization-admin | n/a |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_management_role_arn"></a> [management\_role\_arn](#input\_management\_role\_arn) | ARN of a role in the AWS Organizations management account that the aliased provider assumes to delegate IPAM administration and enable RAM organization sharing. | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | IPAM name; also the prefix of the pool and RAM-share names. | `string` | `"enterprise"` | no |
| <a name="input_network_account_id"></a> [network\_account\_id](#input\_network\_account\_id) | 12-digit ID of the Network account that becomes the delegated VPC IPAM administrator and owns the IPAM. The default provider's credentials must belong to it. | `string` | n/a | yes |
| <a name="input_operating_regions"></a> [operating\_regions](#input\_operating\_regions) | Every Region in which the IPAM manages private address space, including region. | `set(string)` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | IPAM home Region. The delegation, the IPAM, and every RAM share are administered here, and operating\_regions must include it. | `string` | `"us-east-2"` | no |
| <a name="input_regional_pools"></a> [regional\_pools](#input\_regional\_pools) | Allocatable Regional child pools keyed by a short name. Each names its locale (an operating Region), the CIDR it takes from top\_level\_cidr, the default VPC allocation size, optional min/max sizes, tags every allocation must carry, and the account IDs or Organizations principal ARNs it is RAM-shared with. | <pre>map(object({<br/>    locale                            = string<br/>    cidr                              = string<br/>    allocation_default_netmask_length = number<br/>    allocation_min_netmask_length     = optional(number)<br/>    allocation_max_netmask_length     = optional(number)<br/>    allocation_resource_tags          = optional(map(string), {})<br/>    ram_principals                    = optional(set(string), [])<br/>  }))</pre> | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to the IPAM, the pools, and the RAM shares. | `map(string)` | `{}` | no |
| <a name="input_top_level_cidr"></a> [top\_level\_cidr](#input\_top\_level\_cidr) | Enterprise-approved IPv4 range reserved for the non-allocating top-level pool, for example 10.0.0.0/8. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_delegated_admin_account_id"></a> [delegated\_admin\_account\_id](#output\_delegated\_admin\_account\_id) | Account recorded by the management account as the delegated VPC IPAM administrator. |
| <a name="output_ipam_id"></a> [ipam\_id](#output\_ipam\_id) | ID of the IPAM. |
| <a name="output_private_default_scope_id"></a> [private\_default\_scope\_id](#output\_private\_default\_scope\_id) | Private scope that every pool belongs to. |
| <a name="output_regional_pool_ids"></a> [regional\_pool\_ids](#output\_regional\_pool\_ids) | Regional pool IDs keyed by pool key; the values workload VPCs pass as ipam.pool\_id. |
| <a name="output_regional_pools"></a> [regional\_pools](#output\_regional\_pools) | Regional pools keyed by pool key: id, arn, locale, cidr, and the RAM share ARN when shared. |
<!-- END_TF_DOCS -->
