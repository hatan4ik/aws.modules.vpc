# IPAM organization administrator module

Runs in the AWS Organizations management account. It enables AWS RAM sharing
with the organization and delegates VPC IPAM administration to the reviewed
Network account. It does not create an IPAM, pool, VPC, or route; the sibling
`ipam` module owns those Network-account resources.

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

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [aws_ram_sharing_with_organization.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ram_sharing_with_organization) | resource |
| [aws_vpc_ipam_organization_admin_account.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_ipam_organization_admin_account) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_delegated_admin_account_id"></a> [delegated\_admin\_account\_id](#input\_delegated\_admin\_account\_id) | Network-account ID delegated by the AWS Organizations management account to administer VPC IPAM. | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Allocation and ownership tags for the Organization-level IPAM delegation record. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_delegated_admin"></a> [delegated\_admin](#output\_delegated\_admin) | Delegated VPC IPAM administrator recorded by the AWS Organizations management account. |
<!-- END_TF_DOCS -->
