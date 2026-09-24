# IPAM organization administrator submodule

Runs once, in the AWS Organizations management account, before the
[`ipam`](../ipam/README.md) submodule runs in the Network account. It enables
AWS RAM sharing with the organization, so IPAM pool shares can name
organization and OU principals, and delegates VPC IPAM administration to
`delegated_admin_account_id`. It creates no IPAM, pool, VPC, or route.

## What it creates

- `aws_ram_sharing_with_organization.this`: the account-level flag that lets
  RAM shares target the organization and its OUs.
- `aws_vpc_ipam_organization_admin_account.this`: the IPAM delegated
  administrator record, created after the RAM flag so the Network account can
  share pools as soon as it is delegated.

## Rules it enforces

- `delegated_admin_account_id` must be a 12-digit AWS account ID.

## Usage

```hcl
module "ipam_organization_admin" {
  source = "git::https://github.com/hatan4ik/aws.modules.vpc.git//modules/ipam-organization-admin?ref=<commit-sha> # v1.0.0"

  delegated_admin_account_id = "111122223333"
}
```

## Notes

- The provider must use management-account credentials; AWS accepts the
  delegation call from no other account.
- An organization has one IPAM delegated administrator. Changing the account
  replaces the record, which AWS performs as a disable followed by an enable.
- `tags` is accepted so callers can pass their default tags to every
  submodule uniformly, but neither resource here supports tags, so the value
  has no effect.

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
| [aws_ram_sharing_with_organization.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ram_sharing_with_organization) | resource |
| [aws_vpc_ipam_organization_admin_account.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_ipam_organization_admin_account) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_delegated_admin_account_id"></a> [delegated\_admin\_account\_id](#input\_delegated\_admin\_account\_id) | Network-account ID delegated by the AWS Organizations management account to administer VPC IPAM. | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Accepted for interface uniformity with the other submodules; neither resource of this module supports tags, so the value has no effect. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_delegated_admin"></a> [delegated\_admin](#output\_delegated\_admin) | Delegated VPC IPAM administrator recorded by the AWS Organizations management account. |
<!-- END_TF_DOCS -->
